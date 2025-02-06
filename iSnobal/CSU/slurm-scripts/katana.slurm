#!/bin/bash

#SBATCH --job-name=katana
#SBATCH --account=csu-general
#SBATCH --partition=csu

#SBATCH --time=4:00:00
#SBATCH --ntasks=24
#SBATCH --mem=16G

#SBATCH --mail-type=FAIL,END
#SBATCH --mail-user=jmeyer@boisestate.edu

#SBATCH --chdir=/scratch/alpine/c837508519\@colostate.edu/
#SBATCH --output=slurm-%j.out-%N
#SBATCH --error=slurm-%j.err-%N

module load singularity/3.7.4

export OMP_NUM_THREADS=${SLURM_NTASKS}

START_YEAR=2020
START_MONTH=10

## Configuration section ##
# Path to input, output, and config files
BASIN_SETUP=/projects/dmcgrath@colostate.edu/iSnobal-configs/CameronPass
INPUT_DIR=/pl/active/McGrath_Snow/HRRR
KATANA_OUTPUT_DIR=/pl/active/McGrath_Snow/isnobal/CP_katana

KATANA_INI=${BASIN_SETUP}/CP_katana.ini
KATANA_IMAGE=/projects/dmcgrath@colostate.edu/iSnobal/katana/katana.sif

## -------------------------------------------- ##

for MONTH in {0..11}; do
  START=($(date -d "${START_MONTH}/01/${START_YEAR} + ${MONTH} month" "+%m %Y"))
  END=($(date -d "${START_MONTH}/01/${START_YEAR} + $((MONTH + 1)) month" "+%m %Y"))

  MONTH=${START[0]}
  YEAR=${START[1]}
  MONTH_END=${END[0]}
  YEAR_END=${END[1]}

  echo "Processing: ${YEAR}-${MONTH}"

  # Make copy of ini to edit and have as backup
  MONTH_INI="${KATANA_OUTPUT_DIR}/katana_${YEAR}${MONTH}.ini"
  cp ${KATANA_INI} ${MONTH_INI}

  # Update the config to the month processed
  sed -i -e "s/^start_date: .* UTC/start_date: ${YEAR}-${MONTH}-01 00:00:00 UTC/g" ${MONTH_INI}
  sed -i -e "s/^end_date: .* UTC/end_date: ${YEAR_END}-${MONTH_END}-01 00:00:00 UTC/g" ${MONTH_INI}
  # Update config file (line 17) and log path (line 22)
  sed -i -e "17s/katana_wn\.ini/katana_wn_${YEAR}${MONTH}\.ini/" ${MONTH_INI}
  sed -i -e "22s/katana\.log/katana_${YEAR}${MONTH}\.log/" ${MONTH_INI}

  # Map container file path to local
  export SINGULARITY_BIND="${BASIN_SETUP}:/data/topo,${INPUT_DIR}:/data/input,${KATANA_OUTPUT_DIR}:/data/output"
  # Run
  singularity exec ${KATANA_IMAGE} run_katana ${MONTH_INI} 1>&2

  if [ $? -ne 0 ]; then
    >&2 echo "ERROR processing ${YEAR}${MONTH}"
    continue
  fi
done

# Unused  katana output files by iSnobal
find ${KATANA_OUTPUT_DIR} -name *.prj -type f -delete
find ${KATANA_OUTPUT_DIR} -name *_cld.asc -type f -delete
## Unused temporary grib files created by katana
find ${KATANA_OUTPUT_DIR} -name *.grib2 -type f -delete
find ${KATANA_OUTPUT_DIR} -name hrrr.* -type d -empty -delete

