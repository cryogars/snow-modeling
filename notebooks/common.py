import pandas as pd

import matplotlib.pyplot as plt
import matplotlib.dates as mdates
import matplotlib.patches as mpatches
import matplotlib.font_manager as font_manager

import holoviews as hv
from holoviews import dim, opts

from snobedo.lib.dask_utils import start_cluster, client_ip_and_port
from snobedo.snotel import SnotelLocations

from raster_file import RasterFile

from nb_paths import *

# Plot styles
BOKEH_FONT = dict(
    fontsize={
        'title': 24,
        'labels': 24,
        'xlabel': 24,
        'ylabel': 24,
        'xticks': 20,
        'yticks': 20,
        'legend': 24,
    }
)
HV_PLOT_OPTS = dict(
    width=1200,
    height=600,
)
LINE_STYLE = dict(
    line_width=2
)
LEGEND_OPTS = dict(
    legend_position='top_left',
    legend_opts={ 'glyph_width':35 },
    legend_spacing=10,
    legend_padding=30,
)

# Xarray options
# Used in comparison to SNOTEL site locations
COARSEN_OPTS = dict(x=2, y=2)
RESAMPLE_1_DAY_OPTS = dict(time='1D', base=23)

# Plot settings and helpers
plt.rcParams.update(
    {
        'axes.labelsize': 10
    }
)

LEGEND_TEXT = "{0:10} {1:8}"
LEGEND_DATE = "%Y-%m-%d"


def legend_text(label, value, color='none'):
    return mpatches.Patch(
        color=color, label=LEGEND_TEXT.format(label, value)
    )


def add_legend_box(ax, entries):
    ax.legend(
        handles=entries,
        loc='upper left',
        prop=font_manager.FontProperties(
            family='monospace', style='normal', size=8
        ),
    )

def use_hvplot():
    import hvplot.xarray
    import hvplot.pandas
    pd.options.plotting.backend = 'holoviews'
