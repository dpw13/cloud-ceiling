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
    # Use numpy to access memory in 16-bit words
    regs = np.frombuffer(regs_raw, np.uint16, FPGA_REGS_SIZE >> 1)

    id_reg = regs[ID_REG]
    print(f"Initialized. ID = 0x{id_reg:04x}")

    return memmap_fd, regs_raw, regs

# Use PIO for framebuffer
def get_fb(fname="/dev/mem"):
    ledfb_fd = os.open(fname, os.O_RDWR)
    fb_raw = mmap.mmap(ledfb_fd, length=FRAME_SIZE, offset=FIFO_DATA_REGION)
    # Use numpy to access memory in individual bytes. Note that we only
    # reserve the frame buffer itself.
    fb_16 = np.frombuffer(fb_raw, np.uint16, count=FRAME_WORDS, offset=0)

    return (ledfb_fd, fb_raw, fb_16)

parser = argparse.ArgumentParser(
                    prog = 'LED Debugging')

args = parser.parse_args()

memmap_fd, regs_raw, regs = get_regs()
empty = regs[FIFO_EMPTY_COUNT_REG]
print(f"Initial empty count is {empty}")
print(f"Frame size is {FRAME_SIZE} B")

ledfb_fd, fb_raw, fb_16 = get_fb()

try:
    frame = 0
    for i in range(0, FRAME_SIZE//2):
        fb_16[0] = 0x20202020
        last_empty = empty
        empty = regs[FIFO_EMPTY_COUNT_REG]
        empty = regs[FIFO_EMPTY_COUNT_REG]
        if empty > last_empty:
            print(f"Started transmitting at empty count of {last_empty} (data is {2*(8191-last_empty)} B)")
            while empty != last_empty:
                last_empty = empty
                time.sleep(0.01)
                empty = regs[FIFO_EMPTY_COUNT_REG]
            print(f"Transmit finished with empty count of {empty}")
            break
        elif last_empty - empty != 1:
            print(f"At word {i} went from empty count of {last_empty} to {empty}")

    empty = regs[FIFO_EMPTY_COUNT_REG]
    time.sleep(0.1)
    print(f"Finished with empty count of {empty}. Transmitted {i+1} words ({2*i+2} B)")

    for i in range(0, FRAME_SIZE//2 - 1):
        fb_16[0] = 0x20202020

    time.sleep(0.1)
    empty = regs[FIFO_EMPTY_COUNT_REG]
    print(f"Finished with empty count of {empty}. Transmitted {i+1} words ({2*i+2} B)")

finally:
    fb_raw.close()
    os.close(ledfb_fd)
    regs_raw.close()
    os.close(memmap_fd)
