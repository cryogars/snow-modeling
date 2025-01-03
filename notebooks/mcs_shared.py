import rioxarray as rxr
import xarray as xr
import numpy as np

from nb_paths import SNOBAL_DIR, DATA_DIR, GROUP_STORE

# Data Loading
# ============

def load_topo(mask):
    topo = xr.open_dataset(f'{DATA_DIR}/MCS/topo.nc')
    topo.coords['mask'] = (('y', 'x'), mask)
    topo_als = topo.where(topo.mask, drop=True)

    return topo_als


def load_flight(date, masked=True):
    mcs_als = rxr.open_rasterio(
        f"{GROUP_STORE}/MCS-ALS-snowdepth/{date}_MCS-snowdepth_10m.tif",
        masked=True,
        band_as_variables=True,
    )
    mcs_als.name = 'snowdepth'
    # Remove depth values less than 0
    mcs_als.values[mcs_als < 0] = 0
    # Clip depth values above 5
    mcs_als.values[mcs_als > 5] = np.nan
    mcs_als = mcs_als.drop_vars('band').to_dataset()
    mcs_als = mcs_als.squeeze("band")

    # Reduce to flight bounding box
    flight_mask = ~np.isnan(mcs_als.snowdepth)
    if masked:
        mcs_als = mcs_als.where(flight_mask, drop=True)

    return mcs_als, flight_mask


def load_model(date, mask=None):
    if date in ["20231113", "20231228"]:
        year = 2024
    elif date in ["20221208"]:
        year = 2023
    else:
        year = date[0:4]

    isnobal = xr.open_dataset(SNOBAL_DIR / f'wy{year}/mcs/run{date}/snow.nc')
    isnobal = isnobal.drop_vars('time').squeeze("time")
    
    if mask is not None:
        isnobal.coords['mask'] = (('y', 'x'), mask.values)
        isnobal = isnobal.where(isnobal.mask, drop=True)

    return isnobal


def load_day(date):
    # Flight
    mcs_als, flight_mask = load_flight(date)
    isnobal = load_model(date, flight_mask)

    # Difference
    diff = isnobal.thickness.values - mcs_als.snowdepth
    diff = diff.rename('difference')

    return mcs_als, isnobal, diff, flight_mask

# Stats
# =====

def admd(flight, diff):
    median = float(flight.snowdepth.median().values)
    isnobal_median_diff = (diff / median).rename('percent_diff_median')
    return median, isnobal_median_diff

def sdv(depth):
    mean = depth.mean().values
    std = depth.std().values
    return (depth - mean) / std
