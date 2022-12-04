# 
# Flame animation
#

import random
import numpy as np
import math

from constants import *

N_PARTICLES = 1
GROWTH_RATE = 0.2
BURN_RATE_MIN = GROWTH_RATE*0.6
BURN_RATE_MAX = GROWTH_RATE*1.5
MAX_AGE = 8.0

particles = []

COLOR_MAP = [
    # Format:
    # [ age, b, g, r ]
    [ 0.0, 0x40, 0x00, 0x00 ], # blue
    [ 4.0, 0x10, 0x20, 0x00 ], # soft green
    [ 8.0, 0x00, 0x00, 0x00 ], # black
]

AGE_XP = [m[0] for m in COLOR_MAP]
B_FP = [m[1] for m in COLOR_MAP]
G_FP = [m[2] for m in COLOR_MAP]
R_FP = [m[3] for m in COLOR_MAP]

class Drop(object):
    def __init__(self):
        self.x = 0
        self.y = 0
        self.age = 0

        self.radius = 0

        self.color = [0, 0, 0]

        self.reset()

    def reset(self):
        # Set an initial position and speed
        self.radius = 0
        self.burn_rate = random.uniform(BURN_RATE_MIN, BURN_RATE_MAX)
        self.x = random.uniform(0, LED_COUNT)
        self.y = random.uniform(0, STRING_COUNT)

    def update(self):
        self.radius += GROWTH_RATE
        self.age += self.burn_rate

        if (self.age > MAX_AGE):
            self.reset()

    def render(self, fb):
        b = np.interp(self.age, AGE_XP, B_FP)
        g = np.interp(self.age, AGE_XP, G_FP)
        r = np.interp(self.age, AGE_XP, R_FP)

        # Iterate over all pixels covered by this particle
        x_start = max(0, math.floor(self.x - self.radius))
        x_end = min(LED_COUNT-1, math.ceil(self.x + self.radius))
        y_start = max(0, math.floor(self.y - self.radius))
        y_end = min(STRING_COUNT, math.ceil(self.y + self.radius))

        for x_lcl in range(x_start, x_end):
            x_dist = self.x - x_lcl
            x_sq = x_dist * x_dist
            for y_lcl in range(y_start, y_end):
                y_dist = self.y - y_lcl
                y_sq = y_dist * y_dist

                # Calculate distance from this pixel to center
                dist = math.sqrt(x_sq + y_sq)
                # Calculate how close we are to the end of the ring
                rdist = math.abs(dist - self.radius)

                if rdist > 1:
                    continue
                else:
                    byte_idx = 3*(y_lcl + STRING_COUNT*x_lcl)
                    fb[byte_idx + BLUE] = min(255, fb[byte_idx + BLUE] + round(ov*b))
                    fb[byte_idx + GREEN] = min(255, fb[byte_idx + GREEN] + round(ov*g))
                    fb[byte_idx + RED] = min(255, fb[byte_idx + RED] + round(ov*r))

    def __str__(self):
        s = f"x = {self.x:0.2f} y = {self.y:0.2f} radius = {self.radius:0.2f}"
        return s

def init():
    for i in range(0, N_PARTICLES):
        particles.append(Drop())

def render(frame, fb, fb_32):
    fb_32.fill(0)

    for i, p in enumerate(particles):
        p.update()
        #print(f"{i}: {p}")
        p.render(fb)
    