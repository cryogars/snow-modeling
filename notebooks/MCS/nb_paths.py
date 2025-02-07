from pathlib import Path, PurePath

GROUP_STORE = PurePath('/bsushare/hpmarshall-shared/jmeyer')
SNOBAL_STORE = GROUP_STORE.joinpath('iSnobal')
# Model project files
DATA_DIR = SNOBAL_STORE.joinpath('project-data')
# Model output files
SNOBAL_DIR = SNOBAL_STORE.joinpath('MCS/isnobal')
