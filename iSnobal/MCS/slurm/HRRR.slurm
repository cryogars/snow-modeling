#!/bin/bash

#SBATCH --job-name=HRRR
#SBATCH --partition=short

#SBATCH --time=24:00:00
#SBATCH --ntasks=16
#SBATCH --mem=1G

#SBATCH --mail-type=FAIL,END
#SBATCH --mail-user=jmeyer@boisestate.edu

#SBATCH --chdir=/bsuhome/jmeyer/shared-data/iSnobal/HRRR/
#SBATCH --output=slurm-%j.out-%N
#SBATCH --error=slurm-%j.err-%N

set -e

umask 002

YEAR=2025
MONTH=10

for NEXT in {0..9}; do
  CURRENT_MONTH=($(date -d "${YEAR}/${MONTH}/01 + $((10#${NEXT})) month" "+%m %Y"))
  CURRENT_YEAR=${CURRENT_MONTH[1]}
  CURRENT_MONTH=${CURRENT_MONTH[0]}

  >&1 echo "Processing: ${CURRENT_YEAR}${CURRENT_MONTH}"

  micromamba run -n hrrr ${HOME}/projects/iSnobal/model_setup/scripts/HRRR/download_hrrr.sh ${CURRENT_YEAR} ${CURRENT_MONTH}

  if [ $? -ne 0 ]; then
    >&2 echo "ERROR processing ${CURRENT_YEAR}${CURRENT_MONTH}"
    exit
  fi
done

