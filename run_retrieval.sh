###############################################################
# Generate pseudo embedding model for filtering
###############################################################
# python3 preprocess/gen_pseudo_embd.py pretrain/GoogleNews-vectors-negative300.bin pretrain/pseudo_pretrain.txt


###############################################################
# Generate tfidf json
###############################################################
# python3 preprocess/gen_tfidf_json.py -omdb OMDB_dataset/OMDB.json -save OMDB_dataset/omdb_keyword_tfidf.json -topM 20 -weighted 1 -w2v_filter pretrain/pseudo_pretrain.txt 


###############################################################
# Generate partial embedding
###############################################################
# python3 preprocess/gen_partial_embd.py pretrain/GoogleNews-vectors-negative300.bin OMDB_dataset/omdb_keyword_tfidf.json pretrain/partial_embd.txt


###############################################################
# Generate et/tt graphs
###############################################################
# echo "Start generating ET and TT relation edge lists..."
# INFO_PATH="OMDB_dataset/omdb_keyword_tfidf.json"
# EMBD_PATH="pretrain/partial_embd.txt"
# SAVE_PATH="data/"
# GEN_LIB="gen_ice_network/UPLOAD_ice_network"

# for REPK in 20 10
# do
    # for WEIGHTED in 0 1
    # do
        # for MAX_REPK in 20
        # do
            # ET_PATH=$SAVE_PATH"et_top"$REPK"_w"$WEIGHTED".edge"
            # echo "Generating "$ET_PATH
            # python3 $GEN_LIB/gen_et.py -info $INFO_PATH -embd $EMBD_PATH -repk $REPK -max_repk $MAX_REPK -et $ET_PATH -w $WEIGHTED
        # done

        # for EXPK in 10 5
        # do
            # TT_PATH=$SAVE_PATH"tt_top"$REPK"x"$EXPK"_w"$WEIGHTED".edge"
            # echo "Generating "$TT_PATH
            # python3 $GEN_LIB/gen_tt.py -embd $EMBD_PATH -et $ET_PATH -expk $EXPK -tt $TT_PATH -w $WEIGHTED
        # done
    # done
# done
# echo "Finished generating ET and TT relation edge lists."


###############################################################
# Construct ICE network
###############################################################
# SAVE_PATH="data/"
# for REPK in 20
# do
    # for WEIGHTED in 0
    # do
        # ET_PATH=$SAVE_PATH"et_top"$REPK"_w"$WEIGHTED".edge"

        # for EXPK in 10 
        # do
            # TT_PATH=$SAVE_PATH"tt_top"$REPK"x"$EXPK"_w"$WEIGHTED".edge"
            # ICE_FULL_PATH=$SAVE_PATH"ice_full_top"$REPK"x"$EXPK"_w"$WEIGHTED".edge"
            # ICE_ET_PATH=$SAVE_PATH"ice_et_top"$REPK"x"$EXPK"_w"$WEIGHTED".edge"
            # ICE_TT_PATH=$SAVE_PATH"ice_tt_top"$REPK"x"$EXPK"_w"$WEIGHTED".edge"
            # python3 ICE/ICE/construct_graph.py -et $ET_PATH -tt $TT_PATH -ice_full $ICE_FULL_PATH -ice_et $ICE_ET_PATH -ice_tt $ICE_TT_PATH -w $WEIGHTED
        # done
    # done
# done
# echo "Finished generating ET and TT relation edge lists."


###############################################################
# Continuous sensitivity analysis
###############################################################
# DIR="sample_sensi/continuous/"
# SAMP=6000
# TIMES=20
# mkdir $DIR
# for i in 1 
# do
    # ./ICE-manually_set_save_size/ICE/ice -text data/ice_full_top20x10_w0.edge -textrep ${DIR}full.embd -textcontext ${DIR}context.embd -dim 300 -sample $SAMP -save_times $TIMES -neg 5 -alpha 0.025 -thread 26 
    # python3 metric/retrieval_folder.py -dir $DIR -text word.embd -entity item.embd -split full.embd -omdb OMDB_dataset/OMDB.json -seeds OMDB_dataset/genre_seeds.json >> visualize/log/sample_sensi_log_20x10_6k.txt 
# done


###############################################################
# Separate sensitivity analysis
###############################################################
# for i in 1 2 3
# do
    # CUR_DIR=sample_sensi/${i}/
    # mkdir $CUR_DIR
    # for SAMP in 2 4 8 16 32 64 128 256 512 1024 1500 2000 2500 3000 3500 4000 4500 5000
    # do
        # ./ICE/ICE/ice -text data/ice_full_top20x10_w0.edge -textrep ${CUR_DIR}full.embd.${SAMP} -textcontext ${CUR_DIR}context.embd.${SAMP} -dim 300 -sample $SAMP -neg 5 -alpha 0.025 -thread 26 
    # done
    # python3 metric/retrieval_folder.py -dir $CUR_DIR -text word.embd -entity item.embd -split full.embd -omdb OMDB_dataset/OMDB.json -seeds OMDB_dataset/genre_seeds.json >> visualize/log/sample_sensi_log_20x10_5k_sep_${i}.txt 
# done


###############################################################
# Retrieval Task
###############################################################
# mkdir task/
# DIR=task/retrieval/
# mkdir $DIR

# # baseline1: BPT
# if [ -f "data/et_top20_w0_bidir.edge" ]
# then
    # echo "find the file."
# else
    # echo "generating bi-directional graph"
    # awk '{print $2 " " $1 " " $3}' data/et_top20_w0.edge | cat - data/et_top20_w0.edge | sort | uniq > data/et_top20_w0_bidir.edge
# fi
# for i in 1
# do
    # CUR_DIR=${DIR}bpt/
    # mkdir $CUR_DIR
    # for SAMP in 2000 
    # do
        # LINE/linux/line -train data/et_top20_w0_bidir.edge -output ${CUR_DIR}_full.embd.${SAMP} -size 300 -samples $SAMP -negative 5 -rho 0.025 -threads 26
        # sed 1,1d ${CUR_DIR}_full.embd.${SAMP} > ${CUR_DIR}full.embd.${SAMP} # delete the header
        # python3 metric/retrieval_folder.py -dir $CUR_DIR -text word.embd -entity item.embd -split full.embd -omdb OMDB_dataset/OMDB.json -seeds OMDB_dataset/genre_seeds.json >> visualize/log/bpt_log_20x10_2k_${i}.txt 
    # done
# done

# # baseline2: AVGEMB
# CUR_DIR=${DIR}avgemb/
# mkdir ${CUR_DIR}
# python3 AVGEMB/avgemb.py -entity ${CUR_DIR}item.embd -text ${CUR_DIR}word.embd -et data/et_top20_w0.edge -w2v pretrain/partial_embd.txt
# python3 metric/retrieval_folder.py -dir $CUR_DIR -text word.embd -entity item.embd -omdb OMDB_dataset/OMDB.json -seeds OMDB_dataset/genre_seeds.json >> visualize/log/avgemb_log_20x10_2k_${i}.txt

# # baseline3: KBR




