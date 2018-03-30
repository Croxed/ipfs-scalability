#!/usr/bin/env python3
""" Script to run simulation tests on IPFS using ipfsapi and python """

import glob
import os
import subprocess
import sys
import time
from contextlib import contextmanager
import multiprocessing as mp
from random import randint
from urllib.parse import urlparse
from itertools import product

import ipfsapi
# import numpy as np
import pandas as pd

dir_path = os.path.dirname(os.path.realpath(__file__))
file = open(os.path.join(dir_path, "stats.csv"), "a")
# nodes = sys.argv[3:]


@contextmanager
def suppress_stdout():
    """ Suppresses output """
    with open(os.devnull, "w") as devnull:
        old_stdout = sys.stdout
        sys.stdout = devnull
        try:
            yield
        finally:
            sys.stdout = old_stdout


def get_clients():
    """ Extract all clients from the .csv files """
    all_files = glob.glob(os.path.join(dir_path, "clients*.txt"))
    concatenated_df = pd.DataFrame()
    list = []
    for file_ in all_files:
        df = pd.read_csv(file_, index_col=None, header=0)
        list.append(df)
    # df_from_each_file = (pd.read_csv(f) for f in all_files)
    concatenated_df = pd.concat(list)
    # concatenated_df = pd.concat(df_from_each_file, ignore_index=True)
    selected_nodes = []
    size = concatenated_df.shape[0]
    for _ in range(0, int(concatenated_df.shape[0] / 8)):
        index = randint(0, size)
        selected_nodes.extend(concatenated_df.iloc[index])
        concatenated_df.drop(concatenated_df.index[index])
        size -= 1
    return selected_nodes


def subprocess_cmd(command):
    """ Runs command as subprocess """
    # start_time = time.time()
    process = subprocess.Popen(command, stdout=subprocess.PIPE, shell=True)
    process.communicate()[0].strip()
    # time_string = str(time.time() - start_time) + "," + nodes + '\n'
    # file.write(time_string)


def upload_files(node, q):
    """ Uploads all files to given  """
    node_url = urlparse(node)  # Parses the given URL
    print("{}:{}" .format(node_url.hostname, node_url.port))
    ipfs_node = ipfsapi.connect(node_url.hostname, node_url.port)
    res = ipfs_node.add(dir_path + '/files/go-ipfs-0.4.13', recursive=True)
    q.put(res[-1]['Hash'])


def scalability_test(nr_nodes, iterations):
    """ Main method for scalability test """
    nodes = get_clients()
    processes = []
    queue = mp.Queue()
    for node in nodes:
        p = mp.Process(target=upload_files, args=(node, queue))
        processes.append(p)
        p.start()
    # for process in processes:
    #     process.start()
    for process in processes:
        process.join()
    print("Done adding files to nodes")
    # os.environ["IPFS_PATH"] = ipfs_path
    gateway_node = ipfsapi.connect()
    print(queue.get(0))
    for _ in range(0, int(iterations)):
        # subprocess_cmd("ipfs cat /ipfs/%s &> /dev/null" % ipfs_hash)
        start_time = time.time()
        gateway_node.get(queue.get(0))
        time_string = str(time.time() - start_time) + "," + nr_nodes + '\n'
        file.write(time_string)
        subprocess_cmd("rm -rf %{}/{}".format(dir_path, queue.get(0)))


if __name__ == '__main__':
    scalability_test(sys.argv[1], sys.argv[2])
