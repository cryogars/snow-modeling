import numpy as np
import dask

import skgstat as skg

from mcs_shared import load_dem, load_flight_tif


def sample_from_flight(flight, resolution, x_y_slice):
    """
    Load the X and Y slice of that flight.
    Filter snow depth values above 5 and below 0 meters.
    """
    flight_data = load_flight_tif(flight, resolution)
    sample = flight_data.sel(x=x_y_slice[0], y=x_y_slice[1])
    
    # Clip depth values above 5
    sample.values[sample > 5] = np.nan
    # and below 0.1 meters (accuracy of lidar)
    sample.values[sample < 0.1] = np.nan

    return sample

    
def plot_planes(depths, x, y, C):
    """
    Before and after plot for detrending the data

    Args:
        C = Coefficients from plane fitting
    """
    a, b, d = C

    trend_surface = a * x + b * y + d
    detrended = depths - trend_surface

    fig = plt.figure(figsize=(12, 6), dpi=200)
    ax1 = fig.add_subplot(121, projection='3d')
    ax1.plot_surface(x, y, depths, cmap='viridis')
    ax1.set_title('Depths')
    ax1.set_xlabel('X')
    ax1.set_ylabel('Y')
    ax1.set_zlabel('Depth (m)')
    
    # Detrended array
    ax2 = fig.add_subplot(122, projection='3d')
    ax2.plot_surface(x, y, detrended, cmap='viridis')
    ax2.set_title('Detrended Depths')
    ax1.set_xlabel('X')
    ax1.set_ylabel('Y')
    ax1.set_zlabel('Depth (m)')

def detrend_plane(sample):
    """
    Create a plane to detrend the data

    Args:
        sample: XArray DataArray object
    
    Returns:
        Model in form: z = ax + by + d
    """
    values = sample.values[0]
    # values_f = values[::sample_distance, ::sample_distance]
    value_mask = ~np.isnan(values)
    values_f = values[value_mask].flatten()
    
    x, y = np.meshgrid(sample.x.values, sample.y.values)
    x_f = x[value_mask].flatten()
    y_f = y[value_mask].flatten()
    
    # Fit a plane using linear regression
    matrix = np.c_[x_f, y_f, np.ones(x_f.shape)]
    C, residuals, rank, s = np.linalg.lstsq(matrix, values_f, rcond=None)
    
    # Remove trend
    a, b, d = C
    trend_surface = a * x + b * y + d
    detrended = values - trend_surface

    # print(f"Plane equation: z = {a:.6f}x + {b:.6f}y + {d:.6f}")

    # Statistic to return at the end
    median_depth = np.nanmedian(values)
    
    return detrended, x, y, median_depth


@dask.delayed
def variogram_plane_fit(
    flight, resolution, x_y_slice, max_lag, sample_distance
):
    """
    Fit variogram for given flight and sub-window
    """
    sample = sample_from_flight(flight, resolution, x_y_slice)
    detrended, x, y, median_depth = detrend_plane(sample)
    
    # Prepare variogram modeling by sub-sampling using given distance
    detrended = detrended[::sample_distance, ::sample_distance]
    value_mask = ~np.isnan(detrended)
    detrended = detrended[value_mask].flatten()

    x = x[::sample_distance, ::sample_distance][value_mask]
    y = y[::sample_distance, ::sample_distance][value_mask]
    coords = np.array(list(zip(x, y)))
    
    variogram = skg.Variogram(
        coords, detrended,
        estimator='dowd',
        maxlag=max_lag,
    )

    return variogram, variogram.rmse, variogram.describe()['effective_range'], median_depth.round(1)

# ==================
# Section that tried to remove trends by using DEM elevation data only.
# ==================

def detrend_elevation(
    values, dem_indices, elevations, boxplot, dem_bins, ax, ax2
):
    """
    Detrend the data using a linear regression model based
    on the median values of each elevation bin from the box plot.

    Adds boxplots with detrended data
    """
    medians = np.array(
        [item.get_ydata()[1] for item in boxplot['medians']]
    )
    bin_elevations = dem_bins.reshape(-1, 1)
    nan_mask = np.isnan(medians)

    model = LinearRegression()
    model.fit(
        bin_elevations[~nan_mask], medians[~nan_mask]
    )
    # slope = model.coef_[0]
    # intercept = model.intercept_

    # Trendline
    y_pred = model.predict(bin_elevations)
    ax.plot(
        range(0, len(bin_elevations)), y_pred, 
        color='blue', linewidth=1.5, ls='--'
    )

    residual_bins = []
    for index in dem_indices:
        # Bin selection
        bin_vals = values[index]
        elevation_vals = elevations[index]
        # Filter elevations with no data
        elevation_bin_values = elevation_vals[~np.isnan(bin_vals)]
        # Flatten for subtracting the modeled values
        bin_vals = bin_vals[~np.isnan(bin_vals)].flatten()
        # Predict via OLR
        model_values = model.predict(elevation_bin_values.reshape(-1, 1)).flatten()
        # Final values with trend removed
        residual_bins.append(
            bin_vals[~np.isnan(bin_vals)] - model_values
        ) 

    return model, residual_bins


@dask.delayed
def variogram_detrend_elevation(flight, model, resolution, x_y_slice, max_lag, sample_distance):
    """
    Args:
    -----
        model: LinearRegression model 
    """
    dem = load_dem(resolution).sel(x=x_y_slice[0], y=x_y_slice[1])
    sample = sample_from_flight(flight, resolution, x_y_slice)

    values = sample.values[0]
    median_depth = np.nanmedian(values)
    
    # Prepare variogram modeling by sub-sampling using given distance and removing the
    # elevation trend
    elevations = dem.values[0][::sample_distance, ::sample_distance]
    values = values[::sample_distance, ::sample_distance]
    value_mask = ~(np.isnan(values) | np.isnan(elevations))
    # Models from boxplot using the median elevation value
    model_depths = model.predict(elevations[value_mask].reshape(-1,1))
    # Remove trend
    values = values[value_mask] - model_depths

    # Coordinate pairs for variogram
    x, y = np.meshgrid(sample.x.values, sample.y.values)
    x = x[::sample_distance, ::sample_distance][value_mask]
    y = y[::sample_distance, ::sample_distance][value_mask]
    coords = np.array(list(zip(x, y)))
    
    # Release some variables
    del dem, sample
    del elevations, value_mask, model_depths
    del x, y
    
    variogram = skg.Variogram(
        coords, values,
        estimator='dowd',
        maxlag=max_lag,
    )
    # variogram.plot(show=False)

    return variogram, variogram.rmse, variogram.describe()['effective_range'], median_depth.round(1)
