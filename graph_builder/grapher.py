import datetime
import matplotlib as mpl
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
import matplotlib.cbook as cbook
import sys
from matplotlib.backends.backend_pdf import PdfPages
from hurry.filesize import size
from scipy import stats

#------------------------------------------------------------------------------
# accept a dataframe, remove outliers, return cleaned data in a new dataframe
# see http://www.itl.nist.gov/div898/handbook/prc/section1/prc16.htm
#------------------------------------------------------------------------------
def remove_outlier(df_in, col_name):
    q1 = df_in[col_name].quantile(0.25)
    q3 = df_in[col_name].quantile(0.75)
    iqr = q3-q1 #Interquartile range
    fence_low  = q1-1.5*iqr
    fence_high = q3+1.5*iqr
    df_out = df_in.loc[(df_in[col_name] > fence_low) & (df_in[col_name] < fence_high)]
    return df_out

def set_xaxis_title(bp):
    labels = [item.get_text() for item in bp.get_xticklabels()]
    for i in range(len(labels)):
        labels[i] = size(int(labels[i]))
    bp.set_xticklabels(labels)

with PdfPages('plot.pdf') as pdf:
    df = pd.read_csv(sys.argv[1], sep=',', na_values=".")
    # df = remove_outlier(df, 'time')
    # df = df[np.abs(df.time-df.time.mean())<=(3*df.time.std())]
    plt.figure()
    # bp = df.boxplot(column='time', by='nodes', patch_artist=True)
    # df1 = pd.DataFrame(columns=['time','size','file','nodes'])
    # uniqueData = np.unique(df['nodes'])
    # for item in uniqueData:
    #     data = df.query('nodes == @item')
    #     data = data[((data.time - data.time.mean()) / data.time.std()).abs() < 3]
    #     # data = remove_outlier(data, 'time')
    #     # data = data[np.abs(data.time-data.time.mean())<=(3*data.time.std())]
    #     df1 = df1.append(data)
    df = remove_outlier(df, 'time')
    bp = df.boxplot(column='time', by='nodes', patch_artist=True)
    plt.title(df.iloc[0]['file'] + " (" + size(int(df.iloc[0]['size'])) + ")")
    plt.xlabel("Nodes")
    plt.ylabel("Time (s)")
    plt.suptitle("")
    pdf.savefig()
    plt.close()

    uniqueData = np.unique(df['nodes'])
    for item in uniqueData:
        data = df.query('nodes == @item')
        plt.figure()
        it = 0
        for i, row in data.iterrows():
            data.at[i,'nodes'] = it
            it += 1
        bp = data.plot(x='nodes', y='time')
        # set_xaxis_title(bp)
        plt.title("Nodes: " + str(item))
        plt.xlabel("Iteration")
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
