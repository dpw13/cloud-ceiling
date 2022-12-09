#!/usr/bin/env python3

import argparse
import time
import numpy as np

from constants import *

import animation.default
import animation.flame
import animation.drops

parser = argparse.ArgumentParser(
                    prog = 'LED Benchmarking')

parser.add_argument("animation")
parser.add_argument("-n", help="number of frames to render", type=int, default=5000)

args = parser.parse_args()

anim = getattr(animation, args.animation)
anim.init()

# Initialize buffers. We're only benchmarking so just create
# empty arrays in memory.
fb = np.zeros(FRAME_SIZE, dtype=np.uint8)
fb_32 = np.frombuffer(fb, dtype=np.uint32, count=FRAME_WORDS, offset=0)

frame = 0
pt_start = time.process_time_ns()
perf_start = time.perf_counter_ns()

while frame < args.n:
    anim.render(frame, fb, fb_32)
    frame += 1

pt_end = time.process_time_ns()
perf_end = time.perf_counter_ns()

pt_ms = (pt_end - pt_start)/(args.n*1e6)
perf_ms = (perf_end - perf_start)/(args.n*1e6)

print(f"Animation: {args.animation} Frames: {args.n}")
print(f"Process time: {1000*pt_ms:0.2f} us per frame, {1000/pt_ms:0.2f} Hz")
print(f"System time: {1000*perf_ms:0.2f} us per frame, {1000/perf_ms:0.2f} Hz")
