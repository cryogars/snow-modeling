#!/bin/bash

#SBATCH --job-name=SMRF-compact
#SBATCH --account=csu-general
#SBATCH --partition=csu

#SBATCH --time=4:00:00
#SBATCH --ntasks=12
#SBATCH --mem=4G

#SBATCH --mail-type=FAIL,END
#SBATCH --mail-user=jmeyer@boisestate.edu

#SBATCH --chdir=/scratch/alpine/c837508519\@colostate.edu/
#SBATCH --output=slurm-%j.out-%N
#SBATCH --error=slurm-%j.err-%N

module load miniforge
mamba activate snobedo

# Set after module loading to prevent overriding by module call
export OMP_NUM_THREADS=${SLURM_NTASKS}
export XDG_CACHE_HOME=/tmp

umask 0002

# Path to iSnobal output up to the daily outputs (e.g. runYYYYMMDD)
SOURCE_FOLDER="/pl/active/McGrath_Snow/isnobal/wy2022/cp/run*"

compact_smrf() {
  smrf_compactor -sd ${1} --delete-originals
  smrf_compactor -sd ${1} -eb --delete-originals
}

PARALLEL_OPTS='--tag --line-buffer --jobs ${OMP_NUM_THREADS} --tmpdir=/tmp'

export -f compact_smrf
parallel  ${PARALLEL_OPTS} compact_smrf ::: ${SOURCE_FOLDER}

# Add compression to remaining files, not processed by the above
# `compact_smrf` call.
parallel ${PARALLEL_OPTS} \
  nccopy -s -u -d4 {} {.}_c.nc ::: ${SOURCE_FOLDER}/{em,snow}.nc
# Rename and overwrite the old files
if [[ $? -eq 0 ]]; then
  rename _c.nc .nc ${SOURCE_FOLDER}/{em,snow}_c.nc
fi

# Remove all empty log folders
find ${SOURCE_FOLDER} -type d -empty -delete

