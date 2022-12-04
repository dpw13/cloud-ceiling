#
# Flame animation
#

import random
import numpy as np
import wand.image
import wand.drawing

from constants import *

N_PARTICLES = 6
GROWTH_RATE = 0.05
BURN_RATE_MIN = GROWTH_RATE*0.8
BURN_RATE_MAX = GROWTH_RATE*1.5
MAX_AGE = 6.0
THICKNESS = 0.5

particles = []

COLOR_MAP = [
    # Format:
    # [ age, b, g, r ]
    [ 0.0, 0x40, 0x00, 0x00 ], # blue
    [ 4.0, 0x10, 0x20, 0x00 ], # soft green
    [ 6.0, 0x00, 0x00, 0x00 ], # black
]

AGE_XP = np.array([m[0] for m in COLOR_MAP])
B_FP = np.array([m[1] for m in COLOR_MAP], dtype=np.uint8)
G_FP = np.array([m[2] for m in COLOR_MAP], dtype=np.uint8)
R_FP = np.array([m[3] for m in COLOR_MAP], dtype=np.uint8)

BG = wand.color.Color('black')

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
        self.age = 0
        self.radius = 0
        self.burn_rate = random.uniform(BURN_RATE_MIN, BURN_RATE_MAX)
        self.x = random.uniform(0, LED_COUNT)
        self.y = random.uniform(0, STRING_COUNT)

    def update(self):
        self.radius += GROWTH_RATE
        self.age += self.burn_rate

        if (self.age > MAX_AGE):
            self.reset()

    def render(self, draw):
        b = int(round(np.interp(self.age, AGE_XP, B_FP)))
        g = int(round(np.interp(self.age, AGE_XP, G_FP)))
        r = int(round(np.interp(self.age, AGE_XP, R_FP)))

        draw.stroke_color = wand.color.Color(f"#{r:02x}{g:02x}{b:02x}")

        # Don't forget to transpose x and y coordinates in draw calls
        draw.circle((self.y, self.x), (self.y + self.radius, self.x))

    def __str__(self):
        s = f"x = {self.x:0.2f} y = {self.y:0.2f} radius = {self.radius:0.2f} age = {self.age:0.2f}"
        return s

def init():
    for i in range(0, N_PARTICLES):
        particles.append(Drop())

def render(frame, fb, fb_32):
    for i, p in enumerate(particles):
        p.update()

    with wand.drawing.Drawing() as draw:
        draw.fill_color = BG
        draw.stroke_width = THICKNESS
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