import datetime
import sys

import matplotlib as mpl
import matplotlib.cbook as cbook
import matplotlib.pyplot as plt
import matplotlib.ticker as tkr
import numpy as np
import pandas as pd
import seaborn as sns
from matplotlib import rc
from matplotlib.backends.backend_pdf import PdfPages

rc('font', **{'family': 'sans-serif', 'sans-serif': ['Helvetica']})
rc('text', usetex=True)


def set_xaxis_title(bp):
    labels = [item.get_text() for item in bp.get_xticklabels()]
    for i in range(len(labels)):
        # a = r'$\frac{%s}{%s}' % ("1", labels[i])
        labels[i] = r'$\frac{%s}{%s}$' % ("1", labels[i])
    bp.set_xticklabels(labels)


def set_xaxis_seaborn(bp):
    labels = [item.get_text() for item in bp.get_xticklabels()]
    for i in range(len(labels)):
        # a = r'$\frac{%s}{%s}' % ("1", labels[i])
        labels[i] = r'$\frac{%s}{%s}$' % ("1", str(int(1 / float(labels[i]))))
    bp.set_xticklabels(labels)


def replication_calc(row):
    return int(row['nodes']) // int(row['replication'])


def replication_calc_float(row):
    return float(1 / int(row['replication']))


with PdfPages('plot.pdf') as pdf:
    df = pd.read_csv(sys.argv[1], sep=',', na_values=".")
    fig, ax = plt.subplots(facecolor='#FFFFFF')
    # bp = df.boxplot(
    #     column='time',
    #     by=['nodes', 'replication'],
    #     fontsize=8,
    #     ax=ax,
    #     patch_artist=True,
    #     showfliers=False)
    # bp.set_facecolor('#FFFFFF')
    # plt.title(df.iloc[0]['file'])
    # plt.xlabel("Nodes")
    # plt.ylabel("Time (s)")
    # plt.suptitle("")
    # pdf.savefig(figure=fig, facecolor=fig.get_facecolor(), transparent=True)
    # plt.close()
    df['total_rep'] = df.apply(replication_calc, axis=1)
    df['replication_factor'] = df.apply(replication_calc_float, axis=1)
    sns.set_style("whitegrid")
    uniqueData = np.unique(df['total_rep'])
    for item in uniqueData:
        data = df.query('total_rep == @item')
        plt.figure()
        bp = sns.boxplot(x='replication', y='time', hue='nodes', data=data)
        # bp = data.boxplot(
        #     column='time',
        #     by=['replication', 'nodes'],
        #     fontsize=8,
        #     patch_artist=True,
        #     showfliers=False)
        # bp.set_facecolor('#FFFFFF')
        set_xaxis_title(bp)
        # set_xaxis_title(bp, data.iloc[0]['nodes'])
        plt.title(r'Nodes with \textbf{replication}: %s' % item)
        plt.xlabel(r'Replication \textbf{factor}')
        plt.ylabel(r'Download \textbf{time} (s)')
        plt.suptitle("")
        pdf.savefig()
        plt.close()
    uniqueData = np.unique(df['nodes'])
    for item in uniqueData:
        data = df.query('nodes == @item')
        plt.figure()
        bp = sns.boxplot(x='replication_factor', y='time', data=data)
        # bp = data.boxplot(
        #     column='time',
        #     by=['replication_factor'],
        #     fontsize=8,
        #     patch_artist=True,
        #     showfliers=False)
        # bp.set_facecolor('#FFFFFF')
        # set_xaxis_title(bp, data.iloc[0]['nodes'])
        set_xaxis_seaborn(bp)
        plt.title(r'Cluster \textbf{size}: %s' % item)
        plt.xlabel(r'Replication \textbf{factor}')
        plt.ylabel(r'Download \textbf{time} (s)')
        plt.suptitle("")
        pdf.savefig()
        plt.close()
    plt.figure()
    bp = sns.boxplot(x='replication_factor', y='time', data=df)
    # bp = df.boxplot(
    #     column='time',
    #     by='replication_factor',
    #     fontsize=8,
    #     patch_artist=True,
    #     showfliers=False)
    set_xaxis_seaborn(bp)
    plt.title(r'\textbf{Size} : (16, 32, 64, 128)')
    plt.xlabel(r'Replication \textbf{factor}')
    plt.ylabel(r'Download \textbf{time} (s)')
    plt.suptitle("")
    pdf.savefig()
    plt.close()

    sns.set_style("whitegrid")
    ax = sns.barplot(x='replication_factor', y='time', hue='nodes', data=df)
    set_xaxis_seaborn(ax)
    plt.title("Bar plot")
    plt.xlabel(r'Replication \textbf{factor}')
    plt.ylabel(r'Download \textbf{time} (s)')
    plt.suptitle("")
    pdf.savefig()
    plt.close()

    # We can also set the file's metadata via the PdfPages object:
    d = pdf.infodict()
    d['Title'] = 'IPFS scalability test'
    d['Author'] = u'Oscar Wennergren'
    d['CreationDate'] = datetime.datetime(2018, 2, 12)
    d['ModDate'] = datetime.datetime.today()
