#!/usr/bin/env bash
#
# Run for given day. Date format: 2017-10-01 00:00
#

# Initial run, no previous days
micromamba run -n isnoda \
awsm_daily_airflow -c ${HOME}/projects/snow-modeling/iSnobal/configs/MCS_$(date -d "${1} + 1 year" +%Y).ini \
  --no_previous \
  --start_date $1
