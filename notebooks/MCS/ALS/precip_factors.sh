#!/usr/bin/env bash
#
# Calculate precip factor according to Equation 3 in
# Voegeli et. al 2016
#
# $1 - path to iSnobal outputs starting at the WY20XX level
# $2 - path to ALS depth
#
# Loop example:
# for FIL in 202*; do 
#   ~/projects/snow-modeling/notebooks/MCS/ALS/precip_factors.sh ~/shared-data/iSnobal/MCS/isnobal $FIL; 
# done

set -e

# Spatial resolution in meters
RESOLUTION=10
NO_DATA=-9999

ALS_FILE=$(realpath "${2}" | xargs basename)
DATE=${ALS_FILE:0:8}
YEAR=$((10#${DATE:0:4}))
MONTH=$((10#${DATE:4:2}))

if [[ $MONTH -gt 9 ]]; then
    YEAR=$((YEAR + 1))
fi

ISNOBAL_NC="${1}/wy${YEAR}/mcs/run${DATE}/snow.nc"
ISNOBAL_VRT="${1}/wy${YEAR}/mcs/run${DATE}/snow.vrt"
FACTORS_TIF="$(pwd)/${DATE}_precip_factors.tif"

# Get iSnobal simualted depth
gdalwarp -overwrite \
  -r cubic -tr ${RESOLUTION} ${RESOLUTION} \
  -te 601558.000 4862467.500 609431.500 4870872.500 \
  NETCDF:"${ISNOBAL_NC}":thickness ${ISNOBAL_VRT}

# Calculate
gdal_calc.py --co="TILED=YES" --co="COMPRESS=LZW" --co="NUM_THREADS=ALL_CPUS"  \
  --overwrite \
  --calc="A/B" \
  --NoDataValue ${NO_DATA} \
  -A ${ISNOBAL_VRT} \
  -B ${2} \
  --outfile ${FACTORS_TIF}

rm ${ISNOBAL_VRT}
