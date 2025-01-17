#!/usr/bin/env bash
#
# Run for given day. Date format: 2017-10-01
#

module load mambaforge
mamba activate isnoda

INI_FILE_PREFIX="/projects/dmcgrath@colostate.edu/iSnobal-configs/CameronPass/CP_awsm"

# Initial run, no previous days
awsm_daily_airflow -c ${INI_FILE_PREFIX}_$(date -d "${1} + 1 year" +%Y).ini \
  --no_previous \
  --start_date $1
