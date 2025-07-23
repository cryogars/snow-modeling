#!/bin/bash

#SBATCH --job-name=iSnobal
#SBATCH --account=csu-general
#SBATCH --partition=csu
#SBATCH --qos=csu

#SBATCH --time=8:00:00
#SBATCH --ntasks=24
#SBATCH --mem=12G

#SBATCH --mail-type=FAIL,END
#SBATCH --mail-user=__EMAIL__

#SBATCH --chdir=__SCRATCH_PATH__
#SBATCH --output=slurm-%j.out-%N
#SBATCH --error=slurm-%j.err-%N

# Enable CPU Hyper-threading
export OMP_NUM_THREADS=${SLURM_NTASKS}

module load miniforge
mamba activate isnoda

umask 0002

START_DATE="2023-10-01"
WATER_YEAR=$((${START_DATE:0:4} + 1))

awsm -c /projects/dmcgrath@colostate.edu/iSnobal-configs/CameronPass/CP_awsm_${WATER_YEAR}.ini \
  --start_date ${START_DATE} --no_previous
awsm -c /projects/dmcgrath@colostate.edu/iSnobal-configs/CameronPass/CP_awsm_${WATER_YEAR}.ini

