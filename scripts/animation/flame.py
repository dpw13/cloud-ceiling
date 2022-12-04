# 
# Flame animation
#

import random
import numpy as np
import wand.image
import wand.drawing

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

AGE_MAX = 6.0

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

AGE_XP = np.array([m[0] for m in COLOR_MAP])
B_FP = np.array([m[1] for m in COLOR_MAP], dtype=np.uint8)
G_FP = np.array([m[2] for m in COLOR_MAP], dtype=np.uint8)
R_FP = np.array([m[3] for m in COLOR_MAP], dtype=np.uint8)

BG = wand.color.Color('black')

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

    def render(self, draw):
        b = int(round(np.interp(self.age, AGE_XP, B_FP)))
        g = int(round(np.interp(self.age, AGE_XP, G_FP)))
        r = int(round(np.interp(self.age, AGE_XP, R_FP)))

        draw.fill_color = wand.color.Color(f"#{r:02x}{g:02x}{b:02x}")

        # Don't forget to transpose x and y coordinates in draw calls
        # Left: y_min Right: y_max
        # Top: x_min Bottom: x_max
        draw.rectangle(left=self.y_min, right=self.y_max, top=self.x_min, bottom=self.x_max)

    def __str__(self):
        s = f"x = {self.x:0.2f} dx = {self.x_vel:0.2f} y = {self.y:0.2f} dy = {self.y_vel:0.2f} age = {self.age:0.2f}"
        s += f" size = {self.size:0.2f} x_min:max = {self.x_min}:{self.x_max} y_min:max = {self.y_min}:{self.y_max}"
        return s

def init():
    for i in range(0, N_PARTICLES):
        particles.append(Particle())

def render(frame, fb, fb_32):
    for i, p in enumerate(particles):
        p.update()

    with wand.drawing.Drawing() as draw:
        draw.stroke_width = 0

        for i, p in enumerate(particles):
            p.render(draw)
        # ImageMagick exports data with rows as the primary index. We stream data to the
        # framebuffer columns-first to reduce the memory requirements of the FIFO. Rather
        # than generating the image and transposing, just generate a transposed image.
        with wand.image.Image(width=STRING_COUNT, height=LED_COUNT, background=BG) as img:
            # Rasterize drawing primitives
            draw(img)
            # Export pixels in framebuffer format
            pxl_list = img.export_pixels(channel_map='BRG', storage='char')
            # Copy to framebuffer. Ideally this additional copy wouldn't be necessary
            # export_pixels returns a list of int32 and our destination buffer is a list of u8
            np.copyto(fb, pxl_list, casting='unsafe')    