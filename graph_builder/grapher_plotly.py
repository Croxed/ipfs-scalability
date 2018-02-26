import datetime
import plotly.plotly as py
import plotly
from plotly.graph_objs import Scatter, Layout
import plotly.graph_objs as go
# import matplotlib as mpl
import numpy as np
import pandas as pd
# import matplotlib.pyplot as plt
# import matplotlib.cbook as cbook
import sys
from matplotlib.backends.backend_pdf import PdfPages
from hurry.filesize import size

df = pd.read_csv(sys.argv[1], sep=',', na_values=".")
uniqueData = np.unique(df['size'])
df.head()
data = []
for item in uniqueData:
    data1 = df.query('size == @item')
    data.append(go.Box(y=data1['time'],x=data1['nodes'], name="hej"))

plotly.offline.plot(data)
