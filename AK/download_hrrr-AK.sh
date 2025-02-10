#!/usr/bin/env bash
# Download HRRR data for Alaska domain
#
# The AK domain gets run every 3 hours, with hourly forecast time
#
# Can either be given two arguments for year and month:
#   ./download_hrrr-AK.sh YYYY MM (Archive)
# or loop over the dates given as one argument separated by comma.
#   ./download_hrrr-AK.sh YYYYMMDD,YYYYMMDD (Archive)
#
# The third is optional and can specify the archive source. Default
# is to get from Google and can be changed to the University of Utah by
# by passing 'UofU' or Amazon with 'AWS'.

set -e

# HRRR forecast hours (FC) and variable of interests
export HRRR_VARS="HGT:surface|TMP:2 m|RH:2 m|DPT: 2 m|UGRD:10 m|VGRD:10 m|TCDC:|APCP:surface|DSWRF:surface"

# HRRR run hours
# The AK domain is run every 3 hours for all forecast hours
export HRRR_DAY_HOURS=$(seq 0 3 21)
export HRRR_FC_HOURS=(1 2 3)

# Targeted AK domain
export GRIB_AREA="-134.964:-133.893 58.077:58.603" # Simple bounding box for Juneau, Alaska`

# Job control - the defaults require to have 8 CPUs for one script run
## Number of jobs to download in parallel
PARALLEL_JOBS=4
## Number of parallel Grib threads per job
export GRIB_THREADS="-ncpu 2"

# List of possible HRRR download sources
export AWS_ARCHIVE='AWS'
export Google_ARCHIVE='Google'
export Azure_ARCHIVE='Azure'

set_archive_url() {
  if [[ ! -v ALT_DATE ]]; then
    local HRRR_DAY=${DATE}
  else
    local HRRR_DAY=${ALT_DATE}
  fi

  if [ $1 == ${AWS_ARCHIVE} ]; then
      export ARCHIVE_URL="https://noaa-hrrr-bdp-pds.s3.amazonaws.com/hrrr.${HRRR_DAY}/alaska/${FILE_NAME}"
  elif [ $1 == ${Google_ARCHIVE} ]; then
      export ARCHIVE_URL="https://storage.googleapis.com/high-resolution-rapid-refresh/hrrr.${HRRR_DAY}/alaska/${FILE_NAME}"
  elif [ $1 == ${Azure_ARCHIVE} ]; then
      export ARCHIVE_URL="https://noaahrrr.blob.core.windows.net/hrrr/hrrr.${HRRR_DAY}/alaska/${FILE_NAME}"
  fi
}
export -f set_archive_url

check_file_in_archive() {
  set_archive_url $1
  STATUS_CODE=$(curl -s -o /dev/null -I -w "%{http_code}" ${ARCHIVE_URL})

  if [ "${STATUS_CODE}" == "404" ]; then
    >&2 printf "   missing\n"
    return 3
  fi

  >&2 printf "\n"
  unset ALT_DATE
  return 0
}
export -f check_file_in_archive

check_alternate_archive() {
    ARCHIVES=($UofU_ARCHIVE $AWS_ARCHIVE $Google_ARCHIVE $Azure_ARCHIVE)

    >&2 printf "  Checking alternate archive: \n"
    for ALT_ARCHIVE in "${ARCHIVES[@]}"; do
      if [[ "${ALT_ARCHIVE}" == "${ARCHIVE}" ]]; then
        continue
      fi

      >&2 printf "   - ${ALT_ARCHIVE}"
      check_file_in_archive ${ALT_ARCHIVE}
      if [ $? -eq 0 ]; then
        return 0
      fi
    done

    unset ALT_DATE
    touch "${FILE_NAME}.missing"
    return 3
}
export -f check_alternate_archive

check_file_existence(){
  # Check for existing file on disk and that it is not zero in size
  if [[ -s "${FILE_NAME}" ]]; then
    >&1 printf "  exists \n"
    exit 0
  fi
  return 3
}
export -f check_file_existence

get_grib_range(){
  INDEX_FILE="${1}.idx"
  RANGE_GREP="grep -A 1 -B 1 "

  curl -s ${ARCHIVE_URL}.idx -o ${INDEX_FILE}

  export MIN_RANGE=$(${RANGE_GREP} -E "${HRRR_VARS}" ${INDEX_FILE} | cut -d ":" -f 2 | head -n 1)
  export MAX_RANGE=$(${RANGE_GREP} -E "${HRRR_VARS}" ${INDEX_FILE} | cut -d ":" -f 2 | tail -n 1)

  rm ${INDEX_FILE}
}
export -f get_grib_range

download_day(){
  HRRR_DATE=$1
  FC_HOUR=$2
  FILE_NAME="hrrr.t$(printf "%02d" ${HRRR_DATE})z.wrfsfcf0${FC_HOUR}.ak.grib2"

  printf "  File: ${FILE_NAME}"

  # Clean up any old temporary pipes from previous runs
  find . -type p -name "${FILE_NAME}_tmp" -delete
  # Remove any previous downloads of empty grib files
  find . -type f -name ${FILE_NAME} -size 0 -delete
  # Remove any previously missing files in archives and try again
  find . -type f -name "${FILE_NAME}.missing" -size 0 -delete

  # Skip download if the file already exists locally
  check_file_existence

  # Check the available archives for file presence
  check_file_in_archive ${ARCHIVE}
  if [ $? -eq 3 ]; then
    check_alternate_archive
  fi

  # Temporary files for download logic
  TMP_FILE="${FILE_NAME}_tmp"
  mkfifo $TMP_FILE

  # Reduce download size of GRIB file by requesting a specific range
  get_grib_range ${FILE_NAME}

  # Three tiered pipe:
  # * Download the file
  # * Crop to area of interest
  # * Reduce to relevant HRRR variables
  printf '\n'
  curl -s --range ${MIN_RANGE}-${MAX_RANGE} ${ARCHIVE_URL} -o $TMP_FILE | \
  wgrib2 $TMP_FILE -v0 ${GRIB_THREADS} -set_grib_type same -small_grib ${GRIB_AREA} - | \
  wgrib2 - -v0 ${GRIB_THREADS} -match "${HRRR_VARS}" -grib $FILE_NAME >&1

  rm $TMP_FILE

  if [ $? -eq 0 ]; then
    >&1 printf " created \n"
  fi
}
export -f download_day

# Parse the given user inputs
if [[ ! -z $2 ]] && [[ $2 != @($UofU_ARCHIVE|$AWS_ARCHIVE|$Google_ARCHIVE) ]]; then
  export YEAR=$1
  export MONTH=$2
  export LAST_DAY=$(date -d "${MONTH}/01/${YEAR} + 1 month - 1 day" +%d)

  export DATES=($(seq -f "${YEAR}${MONTH}%02g" 1 $LAST_DAY))
else
  IFS=','
  export DATES=($1)
fi

# Set the archive, defaults to Google
if [[ "$2" == "${Azure_ARCHIVE}" ]] || [[ "$3" == "${Azure_ARCHIVE}" ]]; then
  export ARCHIVE=${Azure_ARCHIVE}
elif [[ "$2" == "${AWS_ARCHIVE}" ]] || [[ "$3" == "${AWS_ARCHIVE}" ]]; then
  export ARCHIVE=${AWS_ARCHIVE}
else
  export ARCHIVE=${Google_ARCHIVE}
fi

printf "Getting files from: ${ARCHIVE}\n"

# Get the data
for DATE in "${DATES[@]}"; do
  printf "Processing: $DATE\n"
  export DATE=${DATE}

  FOLDER="hrrr.${DATE}"
  mkdir -p $FOLDER
  pushd $FOLDER > /dev/null

  parallel \
    --color --jobs ${PARALLEL_JOBS} --tagstring "hour-{1}-fc-{2}" download_day \
    ::: ${HRRR_DAY_HOURS[@]} ::: "${HRRR_FC_HOURS[@]}"

  popd > /dev/null
done
