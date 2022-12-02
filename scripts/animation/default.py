# 
# Default test animation
#

from constants import *
import numpy as np

def init():
    pass

def render(frame, fb, fb_32):
    fb_32.fill(0)
    for string_idx in range(0, STRING_COUNT):
        for led_idx in range(0, LED_COUNT):
            # Buffer format is (Pixel/String/Color)
            # 0/0/B, 0/0/R, 0/0/G, 0/1/B, 0/1/R, 0/1/G, ...
            # Base index of Pixel/String is 3*Y + STRING_COUNT*3*X = 3*(Y + STRING_COUNT*X)
            if (led_idx + string_idx + 4*frame) % 8 == 0:
                byte_idx = 3*(string_idx + STRING_COUNT*led_idx)

                fb[byte_idx + BLUE] = 0x20
                fb[byte_idx + GREEN] = 0x20
                fb[byte_idx + RED] = 0x20
