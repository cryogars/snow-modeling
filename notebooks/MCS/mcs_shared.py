import rioxarray as rxr
import xarray as xr
import numpy as np

from nb_paths import SNOBAL_DIR, DATA_DIR, GROUP_STORE
from metloom.pointdata import SnotelPointData

from snobedo.snotel import SnotelLocations


# Constants
# =========

# All available days with ALS flights
# Notes on flights:
# * 20240213 had weather issues, precluding a complete coverage
# * 20210310 has the smallest area of all March month
# * 20231113 too early low snow, no pattern established
ALL_FLIGHT_DATES = [
    "20210310",
    "20220217", "20220317", "20220407",
    "20221208", "20230209", "20230316", "20230405",
    "20231113", "20231228", "20240115", "20240315"
]
ACCUMULATION_FLIGHTS = [
    "20221208", "20230209", "20230316", "20230405",
    "20240115"
]

FIRST_WATER_YEAR = 2020

# Data Loading
# ============

def load_topo(mask):
    topo = xr.open_dataset(f'{DATA_DIR}/MCS/topo.nc')
    topo.coords['mask'] = (('y', 'x'), mask)
    topo_als = topo.where(topo.mask, drop=True)

    return topo_als


def load_flight(date, masked=True):
    resolution=30
    mcs_als = rxr.open_rasterio(
        f"{GROUP_STORE}/MCS-ALS-snowdepth/{resolution}m/{date}_MCS-snowdepth_{resolution}m.tif",
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


def load_snotel_locations():
    # Load coordinates
    snotel_sites = SnotelLocations()
    snotel_sites.load_from_json(DATA_DIR / 'snotel_sites_exact.json')
    return snotel_sites


def mcs_snotel_depth(start_date, end_date):
    mcs_snotel_point = SnotelPointData("637:ID:SNTL", "MCS")
    mcs_snotel = mcs_snotel_point.get_daily_data(
        start_date, end_date,
        [mcs_snotel_point.ALLOWED_VARIABLES.SNOWDEPTH]
    )
    # Convert to cm
    mcs_snotel['SNOWDEPTH_M'] = mcs_snotel.SNOWDEPTH * 0.0254
    # Convert to MST
    return mcs_snotel['SNOWDEPTH_M'].reset_index().set_index("datetime").tz_convert('US/Mountain')['SNOWDEPTH_M']


# Stats
# =====

def sdv(depth):
    mean = depth.mean().values
    std = depth.std().values
    return (depth - mean) / std
