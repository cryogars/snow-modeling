#!/bin/bash

#SBATCH --job-name=katana
#SBATCH --partition=cryogars

#SBATCH --time=12:00:00
#SBATCH --ntasks=32
#SBATCH --mem=64G

#SBATCH --mail-type=FAIL,END
#SBATCH --mail-user=jmeyer@boisestate.edu

#SBATCH --chdir=/bsuhome/jmeyer/scratch-data/
#SBATCH --output=slurm-%j.out-%N
#SBATCH --error=slurm-%j.err-%N

set -e
source ~/.bashrc

# WindNinja is installed via Spack as a tcl module
module activate windninja/3.11.2-gcc-12.1.0-up4e7sr

START_YEAR=2024
START_MONTH=10

## Paths ##
KATANA_OUTPUT_DIR=/bsushare/hpmarshall-shared/jmeyer/iSnobal/MCS/katana/
KATANA_INI=${HOME}/projects/snow-modeling/iSnobal/MCS/configs/katana.ini

for MONTH in {0..9}; do
  START=($(date -d "${START_MONTH}/01/${START_YEAR} + ${MONTH} month" "+%m %Y"))
  END=($(date -d "${START_MONTH}/01/${START_YEAR} + $((MONTH + 1)) month" "+%m %Y"))

  MONTH=${START[0]}
  YEAR=${START[1]}
  MONTH_END=${END[0]}
  YEAR_END=${END[1]}

  echo "Processing: ${YEAR}-${MONTH}"

  # Update the config to the month processed
  sed -i -e "s/^start_date: .* UTC/start_date: ${YEAR}-${MONTH}-01 00:00:00 UTC/g" ${KATANA_INI}
  sed -i -e "s/^end_date: .* UTC/end_date: ${YEAR_END}-${MONTH_END}-01 00:00:00 UTC/g" ${KATANA_INI}

  # Backup the used configuration of the processed month
  cp ${KATANA_INI} ${KATANA_OUTPUT_DIR}katana_${YEAR}${MONTH}.ini

  # Execute the model
  ${HOME}/bin/micromamba run -p "/bsushare/hpmarshall-shared/conda-envs/katana" \
    run_katana ${KATANA_INI}

  if [ $? -ne 0 ]; then
    >&2 echo "ERROR processing ${YEAR}${MONTH}"
    continue
  fi
done

# Unused model files
find ${KATANA_OUTPUT_DIR} -name *.prj -type f -delete
find ${KATANA_OUTPUT_DIR} -name *_cld.asc -type f -delete
## Unused temporary grib files created by katana
find ${KATANA_OUTPUT_DIR} -name *.grib2 -type f -delete
find ${KATANA_OUTPUT_DIR} -name hrrr.* -type d -empty -delete

