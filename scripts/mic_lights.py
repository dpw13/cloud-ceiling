#!/usr/bin/env python3

import argparse
import fcntl
import mmap
import os
import time
import numpy as np

from constants import *

def get_regs(fname="/dev/mem"):
    memmap_fd = os.open(fname, os.O_RDWR)
    regs_raw = mmap.mmap(memmap_fd, length=FPGA_REGS_SIZE, offset=FPGA_REGS_BASE)
    # Use numpy to access memory in 32-bit words
    regs = np.frombuffer(regs_raw, np.uint32, FPGA_REGS_SIZE >> 2)

    id_reg = regs[ID_REG]
    print(f"Initialized. ID = 0x{id_reg:04x}")

    return memmap_fd, regs_raw, regs

parser = argparse.ArgumentParser(
                    prog = 'mic_lights.py')

def auto_int(x: str) -> int:
    return int(x, 0)

parser.add_argument("-i", "--intensity", type=int, default=16)
parser.add_argument("-c", "--color", type=auto_int, default=16)

args = parser.parse_args()

memmap_fd, regs_raw, regs = get_regs()

led_data = 0xE0000000 | (args.intensity << 24) | args.color
print(f"LED data word {led_data:x}")

# See SK9822 documentation
regs[MIC_LED_DATA_REG] = 0 # frame start
#time.sleep(0.001)
for i in range(0, 12):
    regs[MIC_LED_DATA_REG] = led_data
    #time.sleep(0.001)
regs[MIC_LED_DATA_REG] = 0xFFFFFFFF # frame end
