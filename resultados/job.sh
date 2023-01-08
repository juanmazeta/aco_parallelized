#!/bin/bash
#SBATCH -n 1
#SBATCH --job-name=seq_toymodel
#SBATCH -t 00:30:00

module load gnu8/8.3.0

export HOME=/home/juanma/Desktop/TFG/src/aco_parallelized/aco

$HOME/aco $HOME/benchmarks/problema_4155n.bs

