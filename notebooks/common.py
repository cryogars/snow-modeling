import pandas as pd
import numpy as np

import matplotlib.pyplot as plt
import matplotlib.dates as mdates
import matplotlib.patches as mpatches
import matplotlib.font_manager as font_manager
from matplotlib.offsetbox import AnchoredText

import holoviews as hv
from holoviews import dim, opts

from snobedo.lib.dask_utils import start_cluster, client_ip_and_port

# Showing dataframes in notebooks
from IPython.display import display

np.set_printoptions(precision=3, suppress=True)
pd.set_option('display.precision', 2)
pd.set_option('display.float_format', '{:.2f}'.format)

# https://pandas.pydata.org/pandas-docs/stable/user_guide/indexing.html#returning-a-view-versus-a-copy
pd.options.mode.copy_on_write = True

# Plot styles
BOKEH_FONT = dict(
    fontsize={
        'title': 18,
        'labels': 18,
        'xlabel': 16,
        'ylabel': 16,
        'xticks': 14,
        'yticks': 14,
        'legend': 16,
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
        'axes.titlesize': 8,
        'axes.labelsize': 8,
        'xtick.labelsize': 8,
        'ytick.labelsize': 8
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
    hv.extension('bokeh')

    # For image exports
    hv.output(fig='auto', dpi=300)

    pd.options.plotting.backend = 'holoviews'
