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

CONDA_ENV="/bsushare/hpmarshall-shared/conda-envs/isnoda"

${HOME}/bin/micromamba run -p "${CONDA_ENV}" \
  awsm -c ${HOME}/projects/snow-modeling/iSnobal/MCS/configs/MCS_2021.ini \
    --no_previous --start_date 2020-10-01
${HOME}/bin/micromamba run -p "${CONDA_ENV}" \
  awsm -c ${HOME}/projects/snow-modeling/iSnobal/MCS/configs/MCS_2021.ini

