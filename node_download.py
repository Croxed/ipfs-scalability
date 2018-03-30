#!/usr/bin/env python3
""" Script to run simulation tests on IPFS using ipfsapi and python """

import os
import subprocess
import sys
import time
from contextlib import contextmanager
from threading import Thread
from urllib.parse import urlparse

import ipfsapi
# import numpy as np
# import pandas as pd

dir_path = os.path.dirname(os.path.realpath(__file__))
file = open(dir_path + "/stats.csv", "a")
nodes = sys.argv[3:]


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


def subprocess_cmd(command):
    """ Runs command as subprocess """
    start_time = time.time()
    process = subprocess.Popen(command, stdout=subprocess.PIPE, shell=True)
    process.communicate()[0].strip()
    time_string = str(time.time() - start_time) + "," + nodes + '\n'
    file.write(time_string)


def scalability_test(ipfs_hash, iterations):
    """ Main method for scalability test """
    threads = []
    # with suppress_stdout():
    for node in nodes:
        node_url = urlparse(node)  # Parses the given URL
        ipfs_node = ipfsapi.connect(node_url.hostname, node_url.port)
        thread = Thread(
            target=ipfs_node.add(
                dir_path + '/files/go-ipfs-0.4.13',
                recursive=True)).start()
        threads.extend(thread)
    for thread in threads:
        thread.join()
    print("Done adding files to nodes")
    with suppress_stdout():
        # os.environ["IPFS_PATH"] = ipfs_path
        gateway_node = ipfsapi.connect()
        for _ in range(0, int(iterations)):
            # subprocess_cmd("ipfs cat /ipfs/%s &> /dev/null" % ipfs_hash)
            start_time = time.time()
            gateway_node.get(ipfs_hash)
            time_string = str(time.time() - start_time) + "," + nodes + '\n'
            file.write(time_string)
            subprocess_cmd("rm -rf %s/go-ipfs-0.4.13" % dir_path)


if __name__ == '__main__':
    scalability_test(sys.argv[1], sys.argv[2])
