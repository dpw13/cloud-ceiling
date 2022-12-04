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

def get_regs(fname="/dev/mem"):
    memmap = os.open(fname, os.O_RDWR)
    regs_raw = mmap.mmap(memmap, length=FPGA_REGS_SIZE, offset=FPGA_REGS_BASE)
    # Use numpy to access memory in 16-bit words
    regs = np.frombuffer(regs_raw, np.uint16, FPGA_REGS_SIZE >> 1)

    id_reg = regs[ID_REG]
    print(f"Initialized. ID = 0x{id_reg:04x}")

    return regs

def get_fb(fname="/dev/ledfb"):
    ledfb_fd = os.open(fname, os.O_RDWR)
    fb_raw = mmap.mmap(ledfb_fd, length=FRAME_SIZE, offset=0)
    # Use numpy to access memory in individual bytes. Note that we only
    # reserve the frame buffer itself.
    fb = np.frombuffer(fb_raw, np.uint8, FRAME_SIZE)
    fb_32 = np.frombuffer(fb, np.uint32, FRAME_WORDS)

    return (ledfb_fd, fb, fb_32)

parser = argparse.ArgumentParser(
                    prog = 'LED Demo')

parser.add_argument("animation")

args = parser.parse_args()

regs = get_regs()
empty = regs[FIFO_EMPTY_COUNT_REG]
print(f"Initial empty count is {empty}")

#regs[SCRATCH_REG] = 0x9999

ledfb_fd, fb, fb_32 = get_fb()

anim = getattr(animation, args.animation)

anim.init()

frame = 0
while True:
    anim.render(frame, fb, fb_32)

    # Make sure we have room in the FIFO
    empty = regs[FIFO_EMPTY_COUNT_REG]
    while (empty < 2048):
        time.sleep(0.001)
        empty = regs[FIFO_EMPTY_COUNT_REG]
    #print(f"Empty count before frame {frame} is {empty}")

    # Serialize framebuffer to LEDs
    fcntl.ioctl(ledfb_fd, 0, FRAME_SIZE)
    #time.sleep(0.004)
    #status = regs[FIFO_STATUS_REG]

    frame += 1

time.sleep(0.1)

# Turn off LEDs
fb_32.fill(0)
fcntl.ioctl(ledfb_fd, 0, FRAME_SIZE)
time.sleep(0.004)
status = regs[FIFO_STATUS_REG]
empty = regs[FIFO_EMPTY_COUNT_REG]

print(f"FIFO status: 0x{status:04x} empty: {empty}")

fb_raw.close()
os.close(ledfb_fd)
regs_raw.close()
os.close(memmap)