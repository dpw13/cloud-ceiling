#
# Flame animation
#

import random
import numpy as np
import wand.image
import wand.drawing

from constants import *

N_PARTICLES = 12
GROWTH_RATE = 0.2
BURN_RATE_MIN = GROWTH_RATE*0.8
BURN_RATE_MAX = GROWTH_RATE*1.5
MAX_AGE = 8.0
THICKNESS = 0.5

particles = []

COLOR_MAP = [
    # Format:
    # [ age, b, g, r ]
    [ 0.0, 0x40, 0x00, 0x00 ], # blue
    [ 4.0, 0x10, 0x20, 0x00 ], # soft green
    [ 8.0, 0x00, 0x00, 0x00 ], # black
]

AGE_XP = np.array([m[0] for m in COLOR_MAP])
B_FP = np.array([m[1] for m in COLOR_MAP], dtype=np.uint8)
G_FP = np.array([m[2] for m in COLOR_MAP], dtype=np.uint8)
R_FP = np.array([m[3] for m in COLOR_MAP], dtype=np.uint8)

BG = wand.color.Color('black')
# Transparent fill
FILL = wand.color.Color("rgb(0, 0, 0, 0)")

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

def add_args(parser):
    parser.set_defaults(init=init, render=render, set_args=set_args)

def set_args(args):
    pass

def init():
    for i in range(0, N_PARTICLES):
        particles.append(Drop())

def render(frame, fb, fb_32):
    for i, p in enumerate(particles):
        p.update()

    with wand.drawing.Drawing() as draw:
        draw.fill_color = FILL
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
            #np.copyto(fb, pxl_list, casting='unsafe')

            # Reverse every odd line
            for fb_idx in range(0, LED_COUNT*STRING_COUNT//2):
                byte_idx = BYTES_PER_LED*fb_idx
                fb[byte_idx+0] = pxl_list[byte_idx*2+0]
                fb[byte_idx+1] = pxl_list[byte_idx*2+1]
                fb[byte_idx+2] = pxl_list[byte_idx*2+2]
            dst_byte_idx = BYTES_PER_LED*LED_COUNT*STRING_COUNT//2
            for led_idx in range(LED_COUNT-1, -1, -1):
                for string_idx in range(1, STRING_COUNT, 2):
                    #print(f"dest[{dst_byte_idx}] = ({string_idx}, {led_idx})")
                    src_byte_idx = BYTES_PER_LED*(string_idx + STRING_COUNT*led_idx)
                    fb[dst_byte_idx+0] = pxl_list[src_byte_idx+0]
                    fb[dst_byte_idx+1] = pxl_list[src_byte_idx+1]
                    fb[dst_byte_idx+2] = pxl_list[src_byte_idx+2]
                    dst_byte_idx += BYTES_PER_LED

    # original memory order (x,y):
    # 0,0 1,0 2,0 3,0
    # 0,1 1,1 2,1 3,1
    # 0,2 1,2 2,2 3,2
    # 0,3 1,3 2,3 3,3

    # however, here's what order the LEDs actually light with the daisy-chained
    # strips (2 strips of double len):
    # 0,0 2,0 0,1 2,1
    # 0,2 2,2 0,3 2,3
    # 1,3 3,3 1,2 3,2
    # 1,1 3,1 1,0 3,0

    # If we want to render a 4x4 image properly, we need to reorder the image:
    # new(0,0) 0 = orig(0,0) 0
    # new(1,0) 1 = orig(2,0) 2
    # new(2,0) 2 = orig(0,1) 4
    # new(3,0) 3 = orig(2,1) 6
    # new(0,1) 4 = orig(0,2) 8
    # new(1,1) 5 = orig(2,2) A
    # new(2,1) 6 = orig(0,3) C
    # new(3,1) 7 = orig(2,3) E

    # new(0,2) 8 = orig(1,3) D
    # new(1,2) 9 = orig(3,3) F
    # new(2,2) A = orig(1,2) 9
    # new(3,2) B = orig(3,2) B
    # new(0,3) C = orig(1,1) 5
    # new(1,3) D = orig(3,1) 7
    # new(2,3) E = orig(1,0) 1
    # new(3,3) F = orig(3,0) 3

    # x_orig = x_new

    # Similarly, if the index of the LED in memory is 0-F, here's the memory
    # address in the framebuffer of each LED
    # 0   E   1   F
    # 2   C   3   D
    # 4   A   5   B
    # 6   8   7   9
