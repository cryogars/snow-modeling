#!/bin/bash

#SBATCH --job-name=MCS_iSnobal_25
#SBATCH --partition=bsudfq

#SBATCH --time=0-04:00:00
#SBATCH --ntasks=48
#SBATCH --mem=24G

#SBATCH --mail-type=FAIL,END
#SBATCH --mail-user=jmeyer@boisestate.edu

#SBATCH --chdir=/bsuhome/jmeyer/scratch-data/
#SBATCH --output=slurm-%j.out-%N
#SBATCH --error=slurm-%j.err-%N

CONDA_ENV="/bsushare/hpmarshall-shared/conda-envs/isnobal-dev"

${HOME}/bin/micromamba run -p "${CONDA_ENV}" \
    awsm -c ${HOME}/projects/snow-modeling/iSnobal/MCS/configs/MCS_2025.ini \
    -np

