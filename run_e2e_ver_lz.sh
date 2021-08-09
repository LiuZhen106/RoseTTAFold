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


LEN=`tail -n1 $IN | wc -m`

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
conda activate RoseTTAFold
############################################################
# 2. search for templates
############################################################
DB="$PIPEDIR/pdb100_2021Mar03/pdb100_2021Mar03"
if [ ! -s $WDIR/t000_.hhr ]
then
    echo ">>> Running hhsearch <<<"
    HH="hhsearch -b 50 -B 500 -z 50 -Z 500 -mact 0.05 -cpu $CPU -maxmem $MEM -aliw 100000 -e 100 -p 5.0 -d $DB"
    cat $WDIR/t000_.ss2 $WDIR/t000_.msa0.a3m > $WDIR/t000_.msa0.ss2.a3m
    $HH -i $WDIR/t000_.msa0.ss2.a3m -o $WDIR/t000_.hhr -atab $WDIR/t000_.atab -v 0 > $WDIR/log/hhsearch.stdout 2> $WDIR/log/hhsearch.stderr
    echo "<<< hhsearch running Done >>>"
fi

echo $(date +"%F  %T")
############################################################
# 3. end-to-end prediction
############################################################
if [ ! -s $WDIR/t000_.3track.npz ]
then
    echo "<<< Running end-to-end prediction >>>"
    python $PIPEDIR/network/predict_e2e.py \
        -m $PIPEDIR/weights \
        -i $WDIR/t000_.msa0.a3m \
        -o $WDIR/t000_.e2e \
        --hhr $WDIR/t000_.hhr \
        --atab $WDIR/t000_.atab \
        --db $DB 1> $WDIR/log/network.stdout 2> $WDIR/log/network.stderr
    echo "<<< end-to-end prediction Running Done >>>"
fi

conda deactivate
echo $(date +"%F  %T")
echo "***** All Done ******"
