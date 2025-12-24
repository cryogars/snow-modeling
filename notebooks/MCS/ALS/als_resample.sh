#!/usr/bin/env bash
# Steps to change MCS lidar flights to configured resolution
#

set -e

# Spatial resolution in meters
RESOLUTION=10

INPUT=$(realpath $1)

# Ensure the nan value is set on the incoming file
gdal_edit.py -a_nodata nan ${INPUT}

# Name for translated file
NEW_FILE=$(realpath ${1/depth/depth_${RESOLUTION}m})

# Warp to model domain and resolution
gdalwarp -overwrite --optfile ~/.gdalopts \
  -r cubic -tr ${RESOLUTION} ${RESOLUTION} \
  -te 601558.000 4862467.500 609431.500 4870872.500 \
  ${INPUT} ${NEW_FILE}
  