import datetime
import sys

import matplotlib as mpl
import matplotlib.cbook as cbook
import matplotlib.pyplot as plt
import matplotlib.ticker as ticker
import numpy as np
import pandas as pd
import seaborn as sns
from hurry.filesize import size
from matplotlib import rc
from matplotlib.backends.backend_pdf import PdfPages

rc('font', **{'family': 'sans-serif', 'sans-serif': ['Helvetica']})
rc('text', usetex=True)


def set_xaxis_seaborn(bp):
    labels = [item.get_text() for item in bp.get_xticklabels()]
    for i in range(len(labels)):
        # a = r'$\frac{%s}{%s}' % ("1", labels[i])
        labels[i] = r'$\frac{%s}{%s}$' % ("1", str(int(1 / float(labels[i]))))
    bp.set_xticklabels(labels)


def replication_calc_float(row):
    return float(1 / int(row['replication']))


with PdfPages('plot_line.pdf') as pdf:
    df = pd.read_csv(sys.argv[1], sep=',', na_values=".")
    fig, ax = plt.subplots(facecolor='#FFFFFF')
    uniqueData = np.unique(df['nodes'])
    uniqueRep = np.unique(df['replication'])
    line_data = pd.DataFrame(columns=['time', 'nodes', 'replication'])
    index = 0
    for rep in uniqueRep:
        for item in uniqueData:
            data = df.query('nodes == @item & replication == @rep')
            # data = data.query('replication == @rep')
            average = data['time'].mean()
            replication = int(item) // int(rep)
            line_data.loc[index] = [average, item, rep]
            index += 1
    # line_data.set_index('nodes', inplace=True)
    # ax = sns.pointplot(
        # x='nodes', y='time', hue='replication', data=df, estimator=np.mean)
    for key, grp in line_data.groupby(['replication']):
        lbl = r'($\frac{%s}{%s}$)' % ("1", key)
        # ax = sns.pointplot(x='nodes', y='time', hue='replication')
        ax = grp.plot(
            style='.-',
            ax=ax,
            kind='line',
            x='nodes',
            y='time',
            label=lbl,
            grid=True)
    # line_data.plot(style='.-', ax=ax)
    plt.title("IPFS Scalability")
    plt.xlabel(r'Cluster \textbf{size}')
    plt.ylabel(r' Average download \textbf{times} (s)')
    # plt.suptitle("")
    plt.legend(loc='best')
    pdf.savefig(figure=fig, facecolor=fig.get_facecolor(), transparent=True)
    plt.close()

    # We can also set the file's metadata via the PdfPages object:
    d = pdf.infodict()
    d['Title'] = 'IPFS scalability test'
    d['Author'] = u'Oscar Wennergren'
    d['CreationDate'] = datetime.datetime(2018, 2, 12)
    d['ModDate'] = datetime.datetime.today()
