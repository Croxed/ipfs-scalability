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

dir_path = os.path.dirname(os.path.realpath(__file__))
file = open(dir_path + "/stats.csv", "a")
nodes = 0


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
    file_list = glob.glob(dir_path + '/clients*.txt')
    data = []
    for file_path in file_list:
        data.append(np.genfromtxt(file_path))
    distribution = random.sample(data, (len(data) / 8))
    for data in distribution:
        pattern = '(?:http.*://)?(?P<host>[^:/ ]+).?(?P<port>[0-9]*).*'
        match = re.search(pattern, data)
        client = ipfsapi.connect(match.group('host'), int(match.group('port')))
        with suppress_stdout():
            client.add(dir_path + '/files/go-ipfs-0.4.13', recursive=True)
    os.environ["IPFS_PATH"] = IPFS_PATH
    for i in range(0, iterations):
        subprocess.Popen("ipfs cat /ipfs/%s &> /dev/null" % HASH)


if __name__ == '__main__':
    file.write("time,nodes\n")
    global nodes
    nodes = sys.argv[4]
    scalability_test(sys.argv[1], sys.argv[2], sys.argv[3])