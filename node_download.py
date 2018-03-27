#!/usr/bin/env python3
""" Script to run simulation tests on IPFS using ipfsapi and python """

import glob
import os
import random
import re
import sys
import subprocess
from contextlib import contextmanager
import time
import ipfsapi
import numpy as np
import pandas as pd

dir_path = os.path.dirname(os.path.realpath(__file__))
file = open(dir_path + "/stats.csv", "a")
nodes = sys.argv[4]


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


def scalability_test(IPFS_PATH, HASH, iterations):
    """ Main method for scalability test """
    os.environ["IPFS_PATH"] = IPFS_PATH
    for i in range(0, int(iterations)):
        subprocess_cmd("ipfs cat /ipfs/%s &> /dev/null" % HASH)


if __name__ == '__main__':
    file.write("time,nodes\n")
    scalability_test(sys.argv[1], sys.argv[2], sys.argv[3])
