from pathlib import Path, PurePath

GROUP_STORE = PurePath('/bsushare/hpmarshall-shared/jmeyer')
SNOBAL_STORE = GROUP_STORE.joinpath('iSnobal')
DATA_DIR = SNOBAL_STORE.joinpath('project-data')

SNOBAL_DIR = SNOBAL_STORE.joinpath('MCS/isnobal')

