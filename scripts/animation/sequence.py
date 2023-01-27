#
# Default test animation
#

from constants import *
import numpy as np

INTERVAL=32

def add_args(parser):
    parser.set_defaults(init=init, render=render, set_args=set_args)

def set_args(args):
    pass

def init():
    pass

def render(frame, fb, fb_32):
    fb_32.fill(0)
    idx = BYTES_PER_LED*(frame % (LED_COUNT * STRING_COUNT))
    fb[idx+0] = 0x20
    fb[idx+1] = 0x20
    fb[idx+2] = 0x20
