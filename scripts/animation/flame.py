# 
# Flame animation
#

import random
import numpy as np
import math

from constants import *

N_PARTICLES = 10

Y_START_MIN = 0.5
Y_START_MAX = 2.5

X_MIN_VEL =  0.6
X_MAX_VEL =  1.2
Y_MIN_VEL = -0.02
Y_MAX_VEL =  0.02
BURN_RATE_MIN = 0.070
BURN_RATE_MAX = 0.120
# This is approximately the radius, not diameter
SIZE_MIN = 0.4
SIZE_MAX = 4.0

particles = []

COLOR_MAP = [
    # Format:
    # [ age, b, g, r ]
    [ 0.0, 0x00, 0x00, 0x00 ], # black
    [ 1.0, 0x20, 0x00, 0x00 ], # soft blue
    [ 1.5, 0x00, 0x00, 0x00 ], # black
    [ 2.0, 0x00, 0x00, 0x40 ], # red
    [ 3.0, 0x00, 0x80, 0x80 ], # bright yellow
    [ 4.0, 0x00, 0x10, 0x40 ], # dark orange
    [ 6.0, 0x00, 0x00, 0x00 ], # black
]

AGE_XP = [m[0] for m in COLOR_MAP]
B_FP = [m[1] for m in COLOR_MAP]
G_FP = [m[2] for m in COLOR_MAP]
R_FP = [m[3] for m in COLOR_MAP]

AGE_MAX = 6.0

class Particle(object):
    def __init__(self):
        self.x_min = 0
        self.x_max = 0
        self.y_min = 0
        self.y_max = 0
        self.x_vel = 0.0
        self.y_vel = 0.0
        self.burn_rate = 0.0
        self.age = 0

        self.color = [0, 0, 0]

        self.reset()

    def reset(self):
        # Set an initial position and speed
        size = random.uniform(SIZE_MIN, SIZE_MAX)
        self.x_min = -size
        self.x_max = size
        y = random.uniform(Y_START_MIN, Y_START_MAX)
        self.y_min = y - size
        self.y_max = y + size
        self.x_vel = random.uniform(X_MIN_VEL, X_MAX_VEL)
        self.y_vel = random.uniform(Y_MIN_VEL, Y_MAX_VEL)
        self.burn_rate = random.uniform(BURN_RATE_MIN, BURN_RATE_MAX)
        self.age = 0

    def update(self):
        self.x_min += self.x_vel
        self.x_max += self.x_vel
        self.y_min += self.y_vel
        self.y_max += self.y_vel
        self.age += self.burn_rate

        if (self.y_max) < 0 or (self.y_min) > (STRING_COUNT):
            #print(f"Y {self.y_min}:{self.y_max} out of bounds")
            self.reset()
        elif (self.x_min) > (LED_COUNT):
            #print(f"X {self.x_min}:{self.x_max} out of bounds")
            self.reset()
        elif self.age > AGE_MAX:
            self.reset()

    # We consider pixel (0,0) to be a square from (0,0) to (1,1). We
    # could also consider the pixel as (-0.5,-0.5) to (0.5,0.5) but
    # 0,0 to 1,1 makes a lot of the math simpler.

    def overlap(self, x, y):
        # Compute the union of the current pixel and the particle. The area
        # of this union divided by the area of the pixel is the amount of light
        # to contribute to this pixel. The pixel's area is by definition 1x1 so
        # we can omit dividing by the pixel's area.
        union_x_min = max(x, self.x_min)
        union_x_max = min(x + 1.0, self.x_max)
        union_y_min = max(y, self.y_min)
        union_y_max = min(y + 1.0, self.y_max)

        ov = (union_x_max - union_x_min)*(union_y_max - union_y_min)
        #print(f"Union: {x_min:0.2f}:{x_max:0.2f},{y_min:0.2f}:{y_max:0.2f} Area: {ov:0.2f}")

        return ov

    def render(self, fb):
        b = np.interp(self.age, AGE_XP, B_FP)
        g = np.interp(self.age, AGE_XP, G_FP)
        r = np.interp(self.age, AGE_XP, R_FP)

        rb = round(b)
        rg = round(g)
        rr = round(r)

        # Iterate over all pixels covered by this particle
        x_start = max(0, math.floor(self.x_min))
        x_end = min(LED_COUNT-1, math.ceil(self.x_max))
        y_start = max(0, math.floor(self.y_min))
        y_end = min(STRING_COUNT, math.ceil(self.y_max))

        for x_lcl in range(x_start, x_end):
            for y_lcl in range(y_start, y_end):
                byte_idx = 3*(y_lcl + STRING_COUNT*x_lcl)
                # Calculate the overlap between this pixel's location and the box
                # covering the particle
                if (x_lcl == x_start or x_lcl == x_end or y_lcl == y_start or y_lcl == y_end):
                    # Only bother calculating antialiasing on the edge of the particle
                    ov = self.overlap(x_lcl, y_lcl)
                    #print(f"Overlap at {x_lcl},{y_lcl} = {ov}")

                    fb[byte_idx + BLUE] = min(255, fb[byte_idx + BLUE] + round(ov*b))
                    fb[byte_idx + GREEN] = min(255, fb[byte_idx + GREEN] + round(ov*g))
                    fb[byte_idx + RED] = min(255, fb[byte_idx + RED] + round(ov*r))
                else:
                    # On the interior
                    fb[byte_idx + BLUE] = min(255, fb[byte_idx + BLUE] + rb)
                    fb[byte_idx + GREEN] = min(255, fb[byte_idx + GREEN] + rg)
                    fb[byte_idx + RED] = min(255, fb[byte_idx + RED] + rr)

    def __str__(self):
        s = f"x = {self.x:0.2f} dx = {self.x_vel:0.2f} y = {self.y:0.2f} dy = {self.y_vel:0.2f} age = {self.age:0.2f}"
        s += f" size = {self.size:0.2f} x_min:max = {self.x_min}:{self.x_max} y_min:max = {self.y_min}:{self.y_max}"
        return s

def init():
    for i in range(0, N_PARTICLES):
        particles.append(Particle())

def render(frame, fb, fb_32):
    fb_32.fill(0)

    for i, p in enumerate(particles):
        p.update()
        #print(f"{i}: {p}")
        p.render(fb)
    