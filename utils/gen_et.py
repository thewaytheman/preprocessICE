import json
import argparse
from nltk.corpus import stopwords
import re
from sklearn.feature_extraction.text import TfidfVectorizer
from scipy.sparse import dok_matrix
import operator
from tqdm import tqdm
from gensim.models.keyedvectors import KeyedVectors


def read_w2v_from_gensim(path):
    model = KeyedVectors.load_word2vec_format(path, binary=True)
    return model.wv

def load_json(fjson):
    return json.load(open(fjson))

def extract_plot(dataset):
    return {elem["movieId"]:elem["plot"] for elem in dataset}

def preprocess(plot):
    words = re.sub(r'[^\w]', ' ', plot.strip()).split()
    words_lower = [(w.lower()) for w in words]
    return ' '.join(words_lower)

def dict_processor(dict_data, func):
    return {k:preprocess(v) for k, v in dict_data.items()}

def gen_tfidf_edgelist(dict_data, topM, weighted=False, filter_dict=None):
    edgelist = ""
    corpus = []
    tf = TfidfVectorizer(analyzer='word', ngram_range=(1,1), min_df=0, stop_words='english')
    sorted_keys = sorted([int(k) for k in dict_data.keys()])
    for k in sorted_keys:
        corpus.append(dict_data[str(k)])
    tfidf_matrix = tf.fit_transform(corpus)
    feature_names = tf.get_feature_names()
    dok_tfidf_matrix = dok_matrix(tfidf_matrix)
    for j in tqdm(range(dok_tfidf_matrix.shape[0])):
        doc = dok_tfidf_matrix[j]
        value_sorted = sorted(doc.items(), key=operator.itemgetter(1), reverse=True)
        quota = topM
        cache = ""
        for value in value_sorted:
            if weighted:
                word_weight = str(value[1])
            else:
                word_weight = "1"

            has_word = None
            if filter_dict is None or str(feature_names[value[0][1]]) in filter_dict:
                quota -= 1
                has_word = str(feature_names[value[0][1]])

            if has_word is not None:
                cache += "m_%s w_%s %s\n"%(sorted_keys[j], has_word, word_weight)

            if quota <= 0:
                break
        edgelist += cache
    return edgelist

def get_args():
    PARSER = argparse.ArgumentParser(description='Transform OMDB dataset to edge list file.')
    PARSER.add_argument('-omdb', default=None, help='Entity-Text edgelist File Name')
    PARSER.add_argument('-save', default=None, help='Et graph File Name')
    PARSER.add_argument('-topM', default=None, type=int, help='Top M tfidf words are conneceted')
    PARSER.add_argument('-weighted', default=None, type=int, help='0:unweighted / 1:weighted')
    PARSER.add_argument('-w2v_filter', default=None, help='Path: filter vocabs with pretrain mode')
    CONFIG = PARSER.parse_args()
    return CONFIG.omdb, CONFIG.save, int(CONFIG.topM), bool(CONFIG.weighted), CONFIG.w2v_filter

def main():
    omdb, save, topM, weighted, w2v_filter = get_args()
    dataset = load_json(omdb)
    parsed_plot = dict_processor(extract_plot(dataset), preprocess)
    wv = read_w2v_from_gensim(w2v_filter)
    edgelist = gen_tfidf_edgelist(parsed_plot, topM, weighted, wv)
    with open(save, "w") as f:
        f.write(edgelist)


if __name__ == "__main__":
    main()
