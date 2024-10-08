#!/usr/bin/env bash
#
# Link files compacted via `smrf_compactor` for re-running the model
#

SMRF_FILES=(
    'air_temp.nc'
    'cloud_factor.nc'
    'net_solar.nc'
    'percent_snow.nc'
    'precip.nc'
    'precip_temp.nc'
    'snow_density.nc'
    'storm_days.nc'
    'thermal.nc'
    'vapor_pressure.nc'
    'wind_speed.nc'
)

if [[ -z $1 ]] || ! [[ $1 =~ ^[0-9]*$ ]]; then
  echo "Missing required parameter with date to link"
  echo "  Usage: SMRF_linker.sh <YYYYMMDD> "
  exit 1
fi

for FILE in ${SMRF_FILES[@]}; do
  ln -fs smrf_${1}.nc ${FILE}
done

