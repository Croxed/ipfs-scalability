import datetime
import sys

import matplotlib as mpl
import matplotlib.cbook as cbook
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
from hurry.filesize import size
from matplotlib.backends.backend_pdf import PdfPages


with PdfPages('plot_line.pdf') as pdf:
    df = pd.read_csv(sys.argv[1], sep=',', na_values=".")
    fig, ax = plt.subplots(facecolor='#FFFFFF')
    uniqueData = np.unique(df['nodes'])
    line_data = pd.DataFrame(columns=['time', 'nodes'])
    index = 0
    for item in uniqueData:
        data = df.query('nodes == @item')
        average = data['time'].mean()
        line_data.loc[index] = [average, item]
        index += 1
    line_data.set_index('nodes', inplace=True)
    line_data.plot(style='.-', ax=ax)
    # plt.title(df.iloc[0]['file'])
    # plt.xlabel("Nodes")
    # plt.ylabel("Time (s)")
    # plt.suptitle("")
    pdf.savefig(figure=fig, facecolor=fig.get_facecolor(), transparent=True)
    plt.close()

    # We can also set the file's metadata via the PdfPages object:
    d = pdf.infodict()
    d['Title'] = 'IPFS scalability test'
    d['Author'] = u'Oscar Wennergren'
    d['CreationDate'] = datetime.datetime(2018, 2, 12)
    d['ModDate'] = datetime.datetime.today()
