#!/usr/bin/env python3
""" Script to run simulation tests on IPFS using ipfsapi and python """

import glob
import multiprocessing as mp
import os
import random
import subprocess
import sys
import time
from contextlib import contextmanager
from itertools import product
from urllib.parse import urlparse

import ipfsapi
# import numpy as np
import pandas as pd
from filelock import FileLock, Timeout

dir_path = os.path.dirname(os.path.realpath(__file__))
file_out = os.path.join(dir_path, "stats.csv")
file_out_lock = os.path.join(dir_path, "stats.csv.lock")
lock = FileLock(file_out_lock, timeout=2)
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


def get_clients(replication):
    """ Extract all clients from the .csv files """
    all_files = glob.glob(os.path.join(dir_path, "clients_*.txt"))
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
    dist = random.sample(range(0, size), int(size / int(replication)))
    for i in dist:
        selected_nodes.extend(concatenated_df.iloc[i])
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
    print("{}:{}".format(node_url.hostname, node_url.port))
    ipfs_node = ipfsapi.connect(node_url.hostname, node_url.port)
    res = ipfs_node.add(dir_path + '/files/go-ipfs-0.4.13', recursive=True)
    q.put(res[-1]['Hash'])


def download_files(node, iterations, gateway, ipfs_hash, file_size, file,
                   nr_nodes, replication):
    """ Download the given file from IPFS """
    print("Downloading {} times from node {} ".format(iterations, node))
    move_path = os.path.join(dir_path, "newDir_{}".format(node))
    subprocess_cmd("rm -rf {}".format(move_path))
    for _ in range(0, int(iterations)):
        subprocess_cmd("mkdir -p {}".format(move_path))
        start_time = time.time()
        subprocess_cmd("ipfs get {} -o {}".format(ipfs_hash, move_path))
        time_string = str(
            time.time() - start_time
        ) + "," + file_size + "," + file + "," + nr_nodes + "," + "1/{}".format(
            replication) + '\n'
        lock.acquire()
        try:
            open(file_out, "a").write(time_string)
        finally:
            lock.release()
        subprocess_cmd("rm -rf {}".format(move_path))
        gateway.repo_gc()


def scalability_test(nr_nodes, iterations, file, file_size, replication):
    """ Main method for scalability test """
    nodes = get_clients(replication)
    processes = []
    queue = mp.Queue()
    for node in nodes:
        p = mp.Process(target=upload_files, args=(node, queue))
        processes.append(p)
        p.start()
    for process in processes:
        process.join()
    print("Done adding files to nodes")
    gateway = ipfsapi.connect('127.0.0.1', 5001)
    os.environ["IPFS_PATH"] = os.path.join(dir_path, "deploy", "ipfs0")
    IPFS_HASH = queue.get(0)
    print(IPFS_HASH)
    nodes = 10
    node_download = []
    node_iterations = int(iterations) / int(nodes)
    for node in range(0, int(nodes)):
        p = mp.Process(
            target=download_files,
            args=(node, node_iterations, gateway, IPFS_HASH, file_size, file,
                  nr_nodes, replication))
        node_download.append(p)
        p.start()
    for node in node_download:
        node.join()


if __name__ == '__main__':
    scalability_test(sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4],
                     sys.argv[5])
