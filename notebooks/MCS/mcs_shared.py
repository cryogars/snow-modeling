import rasterio
import xarray as xr
import numpy as np
import pandas as pd

from osgeo import gdal
gdal.UseExceptions()

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

MC_ALS = f"{GROUP_STORE}/MCS-ALS-snowdepth"
PRECIP_DIR = f"{MC_ALS}/precip_data"

# Data Loading
# ============
def model_run(resolution, base=False):
    """
    Return file path for resolution at base path if requested.
    Otherwise the default path is returned.
    """
    if base:
        return f"{MC_ALS}/{resolution}m_base/"
    else:
        return f"{MC_ALS}/{resolution}m/"

def load_topo(mask):
    topo = xr.open_dataset(f'{DATA_DIR}/MCS/topo.nc')
    topo.coords['mask'] = (('y', 'x'), mask)
    topo_als = topo.where(topo.mask, drop=True)

    return topo_als


def load_dem(resolution, base_run=False):
    with rasterio.open(
        f"{model_run(resolution, base_run)}/MCS_REFDEM_32611_{resolution}m.tif",
    ) as dem_file:
        dem = dem_file.read(1)
        return dem.where(~np.isnan(dem), drop=True)


def load_als_depth(date, resolution, base_run=False):
    with rasterio.open(
        f"{model_run(resolution, base_run)}/{date}_MCS-snowdepth_{resolution}m.tif",
    ) as flight_tif:
        return flight_tif.read(1)


def load_isnobal_depth(date, resolution, base_run=False):
    with rasterio.open(
        f"{model_run(resolution, base_run)}/{date}_iSnobal_thickness.vrt",
    ) as factors_file:
        return factors_file.read(1)


def load_factors_tif(date, resolution, base_run=False):
    with rasterio.open(
        f"{model_run(resolution, base_run)}/{date}_precip_factors.tif",
    ) as factors_file:
        return factors_file.read(1)


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
        [
            mcs_snotel_point.ALLOWED_VARIABLES.SNOWDEPTH,
            mcs_snotel_point.ALLOWED_VARIABLES.PRECIPITATIONACCUM,
        ]
    )
    # Convert to cm
    mcs_snotel['SNOWDEPTH'] *= 0.0254
    # Convert to mm
    mcs_snotel['ACCUMULATED PRECIPITATION'] *= 25.4
    # Convert to MST
    return mcs_snotel.reset_index().set_index("datetime").tz_convert('US/Mountain')[['SNOWDEPTH', 'ACCUMULATED PRECIPITATION']], mcs_snotel_point


def x_y_snotel(snotel_station):
    """
    Convert Snotel from lon/lat to x/y
    """
    converter = Transformer.from_proj(Proj('EPSG:4326'), Proj('EPSG:32611'), always_xy=True)
    return converter.transform(snotel_station.metadata.x, snotel_station.metadata.y)


def mcs_snotel_csv():
    """
    Load SNOTEL data via local file
    """
    depth = pd.read_csv(
        MC_ALS + '/MCS-SNOTEL.csv',
        parse_dates=['Date'], index_col=['Date'],
        comment='#',
    )
    depth['MCS depth'] *= 0.0254
    depth['MCS SWE'] *= 25.4
    depth['MCS precip accumulated'] *= 25.4
    depth['MCS precip diff'] *= 25.4

    return depth

def get_raster_pixel_value(file, geo_x, geo_y):
    """
    Return value from raster at given geo coordinates
    """
    with gdal.Open(file) as dataset:
        gt = dataset.GetGeoTransform()

        pixel_coords = gdal.ApplyGeoTransform(
            gdal.InvGeoTransform(gt), geo_x, geo_y
        )
        pixel_x, pixel_y = int(pixel_coords[0]), int(pixel_coords[1])

        band = dataset.GetRasterBand(1)

        val_array = band.ReadAsArray(
            xoff=pixel_x, yoff=pixel_y, win_xsize=1, win_ysize=1
        )

        return val_array[0][0]


def get_station_pixel_factors(resolution, station):
    values = []

    geo_x, geo_y = x_y_snotel(station)
    for date in ACCUMULATION_FLIGHTS:
        file = f"{MC_ALS}/{resolution}m_base/{date}_precip_factors.tif"

        value = get_raster_pixel_value(file, geo_x, geo_y)
        date = pd.to_datetime(date)
        values.append((date, value))

    return values


def get_station_pixel_depths(resolution, station):
    values = []

    geo_x, geo_y = x_y_snotel(station)
    for date in ACCUMULATION_FLIGHTS:
        file = f"{MC_ALS}/{resolution}m_base/{date}_MCS-snowdepth_{resolution}m.tif"

        value = get_raster_pixel_value(file, geo_x, geo_y)
        date = pd.to_datetime(date)
        values.append((date, value))

    return values

# Stats
# =====

def sdv(depth):
    mean = depth.mean().values
    std = depth.std().values
    return (depth - mean) / std

