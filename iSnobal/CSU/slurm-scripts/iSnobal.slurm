#!/bin/bash

#SBATCH --job-name=iSnobal
#SBATCH --account=csu-general
#SBATCH --partition=csu

#SBATCH --time=18:00:00
#SBATCH --ntasks=32
#SBATCH --mem=32G

#SBATCH --mail-type=FAIL,END
#SBATCH --mail-user=jmeyer@boisestate.edu

#SBATCH --chdir=/scratch/alpine/c837508519\@colostate.edu/
#SBATCH --output=slurm-%j.out-%N
#SBATCH --error=slurm-%j.err-%N

# Enable CPU Hyper-threading
export OMP_NUM_THREADS=${SLURM_NTASKS}

module load mambaforge
mamba activate isnoda

awsm_daily /projects/dmcgrath@colostate.edu/iSnobal-configs/CameronPass/CP_awsm_2021.ini

