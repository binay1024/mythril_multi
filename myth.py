#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""mythril.py: Bug hunting on the Ethereum blockchain
   http://www.github.com/ConsenSys/mythril
   """
from sys import exit
import mythril.interfaces.cli
import time

time_start = time.time()

def print_time():
   time_end = time.time()
   print('time cost [%ds]'%(time_end-time_start))

 
if __name__ == "__main__":
    mythril.interfaces.cli.main()
    exit()

