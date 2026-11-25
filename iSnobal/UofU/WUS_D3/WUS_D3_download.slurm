#!/bin/bash

#SBATCH --job-name=WUS_D3
#SBATCH --partition=bsudfq

#SBATCH --time=0-02:00:00
#SBATCH --ntasks=1
#SBATCH --mem=4G

#SBATCH --mail-type=FAIL,END
#SBATCH --mail-user=jmeyer@boisestate.edu

#SBATCH --chdir=/bsuhome/jmeyer/scratch-data/
#SBATCH --output=slurm-%j.out-%N
#SBATCH --error=slurm-%j.err-%N

#SBATCH --array=2060,2070,2080,2090          
                                             
CONDA_ENV="wus_d3"
                                             
MAMBA_USE_LOCKFILES=false ${HOME}/bin/micromamba run -n "${CONDA_ENV}" \
  python "/bsuhome/jmeyer/projects/iSnobal/model_setup/input-data/wus_d3/wus_d3_download.py" \
    --gcm cesm2_r11i1p1f1 \
    --scenario ssp370 \
    --bias-corrected \
    --water-year "${SLURM_ARRAY_TASK_ID}" \
    --batch-size 160 \
    --output /bsuscratch/jmeyer/WUS-D3

