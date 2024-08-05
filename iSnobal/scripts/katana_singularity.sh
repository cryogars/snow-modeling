#!/usr/bin/env bash
# Convert docker to singularity
#  singularity build ars-nwrc-katana.sif docker://usdaarsnwrc/katana
#
# - ${1}: Basin setup directory with topo
# - ${2}: Path to HRRR input data
# - ${3}: Output folder for SMRF to ingest it

## Update to actual singularity image ##
KATANA_IMAGE=/bsuhome/jmeyer/project-data/iSnobal/katana/katana.sif
## ---------------------------------- ##

export SINGULARITY_BIND="${1}:/data/topo,${2}:/data/input,${3}:/data/output"

singularity exec ${KATANA_IMAGE} run_katana ${4}
