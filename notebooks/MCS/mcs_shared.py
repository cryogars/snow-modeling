import rioxarray as rxr
import xarray as xr
import numpy as np

from pyproj import Proj, Transformer

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
    "20231113", "20231228", "20240115", "20240315",
    "20250113", "20250129", "20250404", "20250501"
]
ACCUMULATION_FLIGHTS = [
    "20221208", "20230209", "20230316", # "20230405",
    #"20231228",
    "20240115",
    "20250113", "20250129"
]

# Data Loading
# ============

def load_topo(mask):
    topo = xr.open_dataset(f'{DATA_DIR}/MCS/topo.nc')
    topo.coords['mask'] = (('y', 'x'), mask)
    topo_als = topo.where(topo.mask, drop=True)

    return topo_als


def load_dem(resolution):
    dem = rxr.open_rasterio(
        f"{GROUP_STORE}/MCS-ALS-snowdepth/{resolution}m/MCS_REFDEM_32611_{resolution}m.tif",
        masked=True,
        band_as_variables=True,
    )
    return dem.where(~np.isnan(dem), drop=True)


def load_flight_tif(date, resolution, masked=True):
    return rxr.open_rasterio(
        f"{GROUP_STORE}/MCS-ALS-snowdepth/{resolution}m/{date}_MCS-snowdepth_{resolution}m.tif",
        masked=True,
        band_as_variables=True,
    )


def load_flight(date, masked=True):
    mcs_als = load_flight_tif(date, resolution, masked)
    mcs_als.name = 'snowdepth'

    # Remove depth values less than 0
    mcs_als.values[mcs_als < 0] = np.nan
    # Clip depth values above 5
    mcs_als.values[mcs_als > 5] = np.nan

    # Cleanup using rio-xarray, remove band variable
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


def load_day(date, resolution):
    # Flight
    mcs_als, flight_mask = load_flight(date, resolution)
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
    """
    Load SNOTEL data via metloom
    """
    mcs_snotel_point = SnotelPointData("637:ID:SNTL", "MCS")
    mcs_snotel = mcs_snotel_point.get_daily_data(
        start_date, end_date,
        [mcs_snotel_point.ALLOWED_VARIABLES.SNOWDEPTH]
    )
    # Convert to cm
    mcs_snotel['SNOWDEPTH_M'] = mcs_snotel.SNOWDEPTH * 0.0254
    # Convert to MST
    return mcs_snotel['SNOWDEPTH_M'].reset_index().set_index("datetime").tz_convert('US/Mountain')['SNOWDEPTH_M'], mcs_snotel_point


def x_y_snotel(snotel_station):
    """
    Convert Snotel from lon/lat to x/y
    """
    converter = Transformer.from_proj(Proj('EPSG:4326'), Proj('EPSG:32611'), always_xy=True)
    return converter.transform(snotel_station.metadata.x, snotel_station.metadata.y)


# Stats
# =====

def sdv(depth):
    mean = depth.mean().values
    std = depth.std().values
    return (depth - mean) / std

