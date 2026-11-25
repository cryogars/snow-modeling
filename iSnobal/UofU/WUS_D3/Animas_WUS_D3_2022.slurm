#!/bin/bash

#SBATCH --job-name=iSnobal_WUS_2022
#SBATCH --partition=bsudfq

#SBATCH --time=0-08:00:00
#SBATCH --ntasks=48
#SBATCH --mem=24G

#SBATCH --mail-type=FAIL,END
#SBATCH --mail-user=jmeyer@boisestate.edu

#SBATCH --chdir=/bsuhome/jmeyer/scratch-data/
#SBATCH --output=slurm-%j.out-%N
#SBATCH --error=slurm-%j.err-%N

CONDA_ENV="isnobal"

${HOME}/bin/micromamba run -n "${CONDA_ENV}" \
    awsm -c /bsuhome/jmeyer/project-data/iSnobal/WUS-D3/animas_awsm.ini \
    -np

