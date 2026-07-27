#!/usr/bin/env bash
# Steps to change MCS lidar flights to configured resolution
#
# parallel -u micromamba run -n tools ~/projects/snow-modeling/notebooks/MCS/ALS/als_resample.sh ::: ../orig/202*

set -e

# Target spatial resolution in meters
RESOLUTION=100

INPUT_FILE=$(realpath $1)

ALS_FILE=$(basename ${1})
OUTPUT_FILE=$(pwd)/${ALS_FILE/depth/depth_${RESOLUTION}m}
NODATA_VALUE="-999"

# Set up RAM disk paths 
SHM_DIR="/dev/shm/gdal_process_$$"
mkdir -p "$SHM_DIR"

# Temporary file to filter ALS accuracy
DEPTH_MASKED="${SHM_DIR}/flight_mask.tif"
# Temporary files to downsample
FILL_FILE="${SHM_DIR}/filled.tif"

echo "# Processing: ${ALS_FILE}"

# Ensure the nan value is set on the incoming file
gdal_edit.py -a_nodata nan ${INPUT_FILE}

# Filter ALS below accuracy threshold
gdal_calc.py --co="TILED=YES" --co="COMPRESS=LZW" --co="NUM_THREADS=ALL_CPUS"  \
  --overwrite \
  --calc="where(A>=0.1, where(A<5, A, ${NODATA_VALUE}), ${NODATA_VALUE})" \
  --NoDataValue ${NODATA_VALUE} \
  -A ${INPUT_FILE} \
  --outfile ${DEPTH_MASKED}

# Iterative Doubling (0.5m to 4m) as an attempt to fill gaps
for RES in 1 2 4; do
    echo "* Going to ${RES}m"

    # Fill neighbors with window size pixel neighbors
    if [ "$RES" == "1" ]; then
        WINDOW=4
    else
        WINDOW=1
    fi
    
    if [ "$RES" != 4 ]; then
        gdal_fillnodata.py \
            -co="TILED=YES" -co="COMPRESS=LZW" -co="NUM_THREADS=ALL_CPUS" -co="PREDICTOR=3" \
            -md ${WINDOW} -si 0 ${DEPTH_MASKED} ${FILL_FILE}
    fi

    gdalwarp -tr ${RES} ${RES} \
             -r cubic \
             -srcnodata ${NODATA_VALUE} -dstnodata ${NODATA_VALUE} \
             --optfile ~/.gdalopts \
             -multi -wo NUM_THREADS=ALL_CPUS \
             -overwrite ${FILL_FILE} ${DEPTH_MASKED}
done

# Final 100m product at model domain extent
echo "* Final output"
gdalwarp -tr ${RESOLUTION} ${RESOLUTION} \
         -te 601558.000 4862467.500 609431.500 4870872.500 \
         -r cubic \
         -srcnodata $NODATA_VALUE -dstnodata $NODATA_VALUE \
         -ot Float32 -multi -wo NUM_THREADS=ALL_CPUS \
         --optfile ~/.gdalopts \
         -overwrite ${DEPTH_MASKED} ${OUTPUT_FILE}

rm -r ${SHM_DIR}
