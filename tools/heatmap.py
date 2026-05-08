import pandas as pd
import numpy as np
from matplotlib import pyplot as plt
import argparse

parser = argparse.ArgumentParser(description='This program parse core-to-core-latency report and make heat map')
parser.add_argument('-f', '--file', type=str, help='core to core latency csv report', required=True)
parser.add_argument('-o', '--outputfile', type=str, help='processor latency heatmap', required=True)
parser.add_argument('-c', '--core', type=str, help='processor name', required=True)
parser.add_argument('-n', '--number', type=int, help='number of cores', required=True)
args = parser.parse_args()

def load_data(filename):
    m = np.array(pd.read_csv(filename, header=None))
    return np.tril(m) + np.tril(m).transpose()

def show_heapmap(m, title=None, subtitle=None, vmin=None, vmax=None, yticks=True, figsize=None):
    vmin = np.nanmin(m) if vmin is None else vmin
    vmax = np.nanmax(m) if vmax is None else vmax
    black_at = (vmin+3*vmax)/4
    subtitle = "Core-to-core latency" if subtitle is None else subtitle

    isnan = np.isnan(m)

    plt.rcParams['xtick.bottom'] = plt.rcParams['xtick.labelbottom'] = False
    plt.rcParams['xtick.top'] = plt.rcParams['xtick.labeltop'] = True

    figsize = np.array(m.shape)*0.3 + np.array([6,1]) if figsize is None else figsize
    fig, ax = plt.subplots(figsize=figsize, dpi=130)

    fig.patch.set_facecolor('w')

    plt.imshow(np.full_like(m, 0.7), vmin=0, vmax=1, cmap = 'gray') # for the alpha value
    plt.imshow(m, cmap = plt.cm.get_cmap('viridis'), vmin=vmin, vmax=vmax)

    fontsize = 9 if vmax >= 100 else 10

    for (i,j) in np.ndindex(m.shape):
        t = "" if isnan[i,j] else f"{m[i,j]:.1f}" if vmax < 10.0 else f"{m[i,j]:.0f}"
        c = "w" if m[i,j] < black_at else "k"
        plt.text(j, i, t, ha="center", va="center", color=c, fontsize=fontsize)

    plt.xticks(np.arange(m.shape[1]), labels=[f"{i+1}" for i in range(m.shape[1])], fontsize=9)
    if yticks:
        plt.yticks(np.arange(m.shape[0]), labels=[f"CPU {i+1}" for i in range(m.shape[0])], fontsize=9)
    else:
        plt.yticks([])

    #plt.tight_layout()
    plt.title(f"{title}\n" +
              f"{subtitle}\n" +
              f"Min={vmin:0.1f}ns Median={np.nanmedian(m):0.1f}ns Max={vmax:0.1f}ns",
              fontsize=11, linespacing=1.5)

    plt.savefig(args.outputfile)

cpu = args.core
fname = args.file
m = load_data(fname)

n=args.number

show_heapmap(m[:n,:n], title=f"{cpu}")