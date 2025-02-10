#!/usr/bin/env bash

# Steps to change MCS lidar flights to configured resolution

# Spatial resolution in meters
RESOLUTION=10

INPUT=$(realpath $1)

# Ensure the nan value is set on the incoming file
gdal_edit.py -a_nodata nan ${INPUT}

# Name for translated file
NEW_FILE=$(realpath ${1/depth/depth_${RESOLUTION}m})

# Remove old if exists
[[ -f ${NEW_FILE} ]] && rm ${NEW_FILE}

# Translate to model domain and resolution
gdal_translate --optfile ${HOME}/.gdalopts \
  -r average -tr ${RESOLUTION} ${RESOLUTION} \
  -projwin 594356.438 4877419.000 616456.438 4855619.000 \
  ${INPUT} ${NEW_FILE}
  