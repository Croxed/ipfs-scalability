import datetime
import matplotlib as mpl
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
import matplotlib.cbook as cbook
import sys
from matplotlib.backends.backend_pdf import PdfPages
from hurry.filesize import size

def set_xaxis_title(bp):
    labels = [item.get_text() for item in bp.get_xticklabels()]
    for i in range(len(labels)):
        labels[i] = size(int(labels[i]))
    bp.set_xticklabels(labels)

with PdfPages('plot.pdf') as pdf:
    df = pd.read_csv(sys.argv[1], sep=',', na_values=".")
    uniqueData = np.unique(df['size'])
    for item in uniqueData:
        data = df.query('size == @item')
        plt.figure()
        bp = data.boxplot(column='time', by='nodes', patch_artist=True)
        # set_xaxis_title(bp)
        plt.title(data.iloc[0]['file'] + " (" + size(int(data.iloc[0]['size'])) + ")")
        plt.xlabel("Nodes")
        plt.ylabel("Time (s)")
        plt.suptitle("")
        pdf.savefig()
        plt.close()

    # We can also set the file's metadata via the PdfPages object:
    d = pdf.infodict()
    d['Title'] = 'IPFS scalability test'
    d['Author'] = u'Oscar Wennergren'
    d['CreationDate'] = datetime.datetime(2018, 2, 12)
    d['ModDate'] = datetime.datetime.today()
