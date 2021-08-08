#!/bin/bash

# make the script stop when error (non-true exit code) is occured
set -e

############################################################
# >>> conda initialize >>>
__conda_setup="$('conda' 'shell.bash' 'hook' 2> /dev/null)"
eval "$__conda_setup"
unset __conda_setup
# <<< conda initialize <<<
############################################################

SCRIPT=`realpath -s $0`
export PIPEDIR=`dirname $SCRIPT`

CPU="12"  # number of CPUs to use
MEM="20" # max memory (in GB)

# Inputs:
IN="$1"                # input.fasta
WDIR=`realpath -s $2`  # working folder

mkdir -p $WDIR/log

############################################################
# 1. Prepared input files: MSA & predict secondary structure
# Generate t000_.msa0.a3m by https://toolkit.tuebingen.mpg.de/tools/hhblits
# Generate t000_.msa0.horiz by http://bioinf.cs.ucl.ac.uk/psipred/
############################################################
if [ ! -s $WDIR/t000_.msa0.a3m ]
then
    echo t000_.msa0.a3m" isn't exist!"
	exit
else
    sed -i '/^#/d' t000_.msa0.a3m
fi

if [ ! -s t000_.msa0.horiz ]
then
	echo t000_.msa0.horiz" isn't exist!"
	exit
fi

echo "Starting......"
echo $(date +"%F  %T")

if [ ! -s $WDIR/t000_.ss2 ]
then	
	(
	echo ">ss_pred"
	grep "^Pred" t000_.msa0.horiz | awk '{print $2}'
	echo ">ss_conf"
	grep "^Conf" t000_.msa0.horiz | awk '{print $2}'
	) | awk '{if(substr($1,1,1)==">") {print "\n"$1} else {printf "%s", $1}} END {print ""}' | sed "1d" > t000_.ss2
fi

conda activate RoseTTAFold
############################################################
# 2. search for templates
############################################################
DB="$PIPEDIR/pdb100_2021Mar03/pdb100_2021Mar03"
if [ ! -s $WDIR/t000_.hhr ]
then
    echo ">>> Running hhsearch <<<"
    HH="hhsearch -b 50 -B 500 -z 50 -Z 500 -mact 0.05 -cpu $CPU -maxmem $MEM -aliw 100000 -p 10.0 -d $DB"
	## HH="hhsearch -b 50 -B 500 -z 50 -Z 500 -mact 0.05 -cpu $CPU -maxmem $MEM -aliw 10000 -qid 10 -p 10.0 -d $DB"
    cat $WDIR/t000_.ss2 $WDIR/t000_.msa0.a3m > $WDIR/t000_.msa0.ss2.a3m
    $HH -i $WDIR/t000_.msa0.ss2.a3m -o $WDIR/t000_.hhr -atab $WDIR/t000_.atab -v 0 > $WDIR/log/hhsearch.stdout 2> $WDIR/log/hhsearch.stderr
    echo "<<< hhsearch runing Done >>>"
fi

echo $(date +"%F  %T")
############################################################
# 3. predict distances and orientations
# Use cuda if it was available, else use cpu
############################################################
if [ ! -s $WDIR/t000_.3track.npz ]
then
    echo ">>> Predicting distance and orientations <<<"
    python $PIPEDIR/network/predict_pyRosetta.py \
        -m $PIPEDIR/weights \
        -i $WDIR/t000_.msa0.a3m \
        -o $WDIR/t000_.3track \
        --hhr $WDIR/t000_.hhr \
        --atab $WDIR/t000_.atab \
        --db $DB 1> $WDIR/log/network.stdout 2> $WDIR/log/network.stderr
    echo "<<< predict_pyRosetta.py running Done >>>"
fi

echo $(date +"%F  %T")
############################################################
# 4. perform modeling
############################################################
mkdir -p $WDIR/pdb-3track

conda deactivate
conda activate folding

for m in 0 1 2
do
    for p in 0.05 0.15 0.25 0.35 0.45
    do
        for ((i=0;i<1;i++))
        do
            if [ ! -f $WDIR/pdb-3track/model${i}_${m}_${p}.pdb ]; then
                echo "python -u $PIPEDIR/folding/RosettaTR.py --roll -r 3 -pd $p -m $m -sg 7,3 $WDIR/t000_.3track.npz $IN $WDIR/pdb-3track/model${i}_${m}_${p}.pdb"
            fi
        done
    done
done > $WDIR/parallel.fold.list

N=`cat $WDIR/parallel.fold.list | wc -l`
if [ "$N" -gt "0" ]; then
    echo ">>> Running parallel RosettaTR.py <<<"
    parallel -j $CPU < $WDIR/parallel.fold.list > $WDIR/log/folding.stdout 2> $WDIR/log/folding.stderr
    echo "<<< parallel RosettaTR.py running Done >>>"
fi

echo $(date +"%F  %T")
############################################################
# 5. Pick final models
############################################################
count=$(find $WDIR/pdb-3track -maxdepth 1 -name '*.npz' | grep -v 'features' | wc -l)
if [ "$count" -lt "15" ]; then
    # run DeepAccNet-msa
    echo ">>> Running DeepAccNet-msa <<<"
    python $PIPEDIR/DAN-msa/ErrorPredictorMSA.py --roll -p $CPU $WDIR/t000_.3track.npz $WDIR/pdb-3track $WDIR/pdb-3track 1> $WDIR/log/DAN_msa.stdout 2> $WDIR/log/DAN_msa.stderr
    echo "<<< DeepAccNet-msa running Done >>>"
fi

if [ ! -s $WDIR/model/model_5.crderr.pdb ]
then
    echo ">>> Picking final models <<<"
    python -u -W ignore $PIPEDIR/DAN-msa/pick_final_models.div.py \
        $WDIR/pdb-3track $WDIR/model $CPU > $WDIR/log/pick.stdout 2> $WDIR/log/pick.stderr
    echo "<<< Final models saved in: $2/model >>>"
fi

conda deactivate
echo $(date +"%F  %T")
echo "****** All Done ******"
