#!/bin/bash

#SBATCH --job-name=MCS_iSnobal
#SBATCH --partition=cryogars

#SBATCH --time=2-00:00:00
#SBATCH --ntasks=32
#SBATCH --mem=128G

#SBATCH --mail-type=FAIL,END
#SBATCH --mail-user=jmeyer@boisestate.edu

#SBATCH --chdir=/bsuhome/jmeyer/scratch-data/
#SBATCH --output=slurm-%j.out-%N
#SBATCH --error=slurm-%j.err-%N

${HOME}/bin/micromamba run -n isnoda \
  awsm -c ${HOME}/projects/snow-modeling/iSnobal/configs/MCS_2024.ini

