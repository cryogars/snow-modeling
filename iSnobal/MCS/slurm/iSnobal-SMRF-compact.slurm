#!/bin/bash

#SBATCH --job-name=SMRF-compact
#SBATCH --partition=cryogars

#SBATCH --time=6:00:00
#SBATCH --ntasks=12
#SBATCH --mem=16G

#SBATCH --mail-type=FAIL,END
#SBATCH --mail-user=jmeyer@boisestate.edu

#SBATCH --chdir=/bsuhome/jmeyer/scratch-data/
#SBATCH --output=slurm-%j.out-%N
#SBATCH --error=slurm-%j.err-%N

export OMP_NUM_THREADS=${SLURM_NTASKS}

export MAMBA_EXE='/bsuhome/jmeyer/bin/micromamba'
eval "$($MAMBA_EXE 'shell' 'hook' '-s' 'bash' '-r' '/bsuhome/jmeyer/micromamba')"
micromamba activate "/bsuhome/jmeyer/micromamba/envs/isnoda"
micromamba activate --stack "/bsuhome/jmeyer/micromamba/envs/tools"

# Path to iSnobal output up to the daily outputs (e.g. runYYYYMMDD)
SOURCE_FOLDER="${HOME}/shared-data/iSnobal/MCS/isnobal/wy2021/mcs/run20210[3,4,5,6,7]*"

compact_smrf() {
  smrf_compactor -sd ${1} --delete-originals
}

export -f compact_smrf
parallel --tag --line-buffer --jobs ${OMP_NUM_THREADS} compact_smrf ::: ${SOURCE_FOLDER}

# Add compression to remaining files, not processed by the above
# `smrf_compactor` call. Utilizes the `parallel` command and tools from `cdo`.
parallel --tag --line-buffer --jobs ${OMP_NUM_THREADS} \
  nccopy -s -u -d4 {} {.}_c.nc ::: ${SOURCE_FOLDER}/{em,snow}.nc
rename _c.nc .nc ${SOURCE_FOLDER}/{em,snow}_c.nc

# Remove all empty log folders
find ${SOURCE_FOLDER} -type d -empty -delete
