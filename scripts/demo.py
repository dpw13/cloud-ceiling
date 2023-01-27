#!/usr/bin/env python3

import argparse
import fcntl
import mmap
import os
import time
import numpy as np

from constants import *

import animation.default
import animation.flame
import animation.drops
import animation.solid

def get_regs(fname="/dev/mem"):
    memmap_fd = os.open(fname, os.O_RDWR)
    regs_raw = mmap.mmap(memmap_fd, length=FPGA_REGS_SIZE, offset=FPGA_REGS_BASE)
    # Use numpy to access memory in 16-bit words
    regs = np.frombuffer(regs_raw, np.uint16, FPGA_REGS_SIZE >> 1)

    id_reg = regs[ID_REG]
    print(f"Initialized. ID = 0x{id_reg:04x}")

    return memmap_fd, regs_raw, regs

def get_fb(fname="/dev/ledfb"):
    ledfb_fd = os.open(fname, os.O_RDWR)
    fb_raw = mmap.mmap(ledfb_fd, length=FRAME_SIZE, offset=0)
    # Use numpy to access memory in individual bytes. Note that we only
    # reserve the frame buffer itself.
    fb = np.frombuffer(fb_raw, np.uint8, count=FRAME_SIZE, offset=0)
    fb_32 = np.frombuffer(fb, np.uint32, count=FRAME_WORDS, offset=0)

    return (ledfb_fd, fb_raw, fb, fb_32)

parser = argparse.ArgumentParser(
                    prog = 'demo.py')

parser.add_argument("--blank", action="store_true")

sp = parser.add_subparsers(title="animation options")

parser_default = sp.add_parser("default")
animation.default.add_args(parser_default)

parser_flame = sp.add_parser("flame")
animation.flame.add_args(parser_flame)

parser_drops = sp.add_parser("drops")
animation.drops.add_args(parser_drops)

parser_solid = sp.add_parser("solid")
animation.solid.add_args(parser_solid)

args = parser.parse_args()
args.set_args(args)

memmap_fd, regs_raw, regs = get_regs()
empty = regs[FIFO_EMPTY_COUNT_REG]
print(f"Initial empty count is {empty}")
print(f"Frame size is {FRAME_SIZE}")

ledfb_fd, fb_raw, fb, fb_32 = get_fb()

args.init()

try:
    frame = 0
    while True:
        args.render(frame, fb, fb_32)

        # Make sure we have room in the FIFO
        empty = regs[FIFO_EMPTY_COUNT_REG]
        empty = regs[FIFO_EMPTY_COUNT_REG]
        while (empty < 2048):
            time.sleep(0.001)
            empty = regs[FIFO_EMPTY_COUNT_REG]
        #print(f"Empty count before frame {frame} is {empty}")

        # Serialize framebuffer to LEDs
        fcntl.ioctl(ledfb_fd, 0, FRAME_SIZE)
        time.sleep(0.01)

        #empty = regs[FIFO_EMPTY_COUNT_REG]
        #empty = regs[FIFO_EMPTY_COUNT_REG]
        #print(f"Empty count after frame {frame} is {empty}")

        #status = regs[FIFO_STATUS_REG]
        #print(f"Status: 0x{status:04x}")

        frame += 1

except KeyboardInterrupt:
    print("Exiting...")
    # Give system to finish its last ioctl
    time.sleep(0.1)

    empty = regs[FIFO_EMPTY_COUNT_REG]
    empty = regs[FIFO_EMPTY_COUNT_REG]
    print(f"Empty count at exit is {empty}")

    # Turn off LEDs
    if args.blank:
        fb_32.fill(0)
        time.sleep(0.01)
        fcntl.ioctl(ledfb_fd, 0, FRAME_SIZE)
        time.sleep(0.01)

    status = regs[FIFO_STATUS_REG]
    status = regs[FIFO_STATUS_REG]
    empty = regs[FIFO_EMPTY_COUNT_REG]

    print(f"FIFO status: 0x{status:04x} empty: {empty}")

finally:
    fb_raw.close()
    os.close(ledfb_fd)
    regs_raw.close()
    os.close(memmap_fd)
