#
# Weather simulation
#

from constants import *
import numpy as np
import wand.image
import wand.drawing

from utils import interpolate_into

SKY_COLOR_MAP = [
    # Format:
    # [ age, r, g, b ]
    [  0.0, 0x01, 0x01, 0x06 ], # "Cetacean Blue"
    [  4.0, 0x01, 0x01, 0x06 ], # "Cetacean Blue"
    [  5.0, 0x01, 0x03, 0x08 ], # "Maastricht Blue"
    [  6.0, 0x07, 0x05, 0x0C ], # "Regalia"
    [  6.5, 0x10, 0x09, 0x0B ], # dusty rose
    [  7.0, 0x13, 0x11, 0x0C ], # straw yellow
    [  7.5, 0x17, 0x16, 0x13 ], # pale cream
    [  8.0, 0x17, 0x18, 0x19 ], # light gray-blue
    [  8.5, 0x19, 0x1D, 0x22 ], # medium blue
    [  9.0, 0x0B, 0x26, 0x2F ], # medium blue
    [ 10.5, 0x04, 0x1F, 0x3D ], # deep day blue
    [ 15.0, 0x04, 0x1F, 0x3D ], # deep day blue
    [ 15.5, 0x0B, 0x26, 0x2F ], # medium blue
    [ 16.0, 0x1F, 0x1B, 0x0E ], # "Shandy"
    [ 16.5, 0x21, 0x14, 0x0B ], # "Sandy Brown"
    [ 17.0, 0x1C, 0x0A, 0x09 ], # "Sunset Orange"
    [ 17.5, 0x0C, 0x09, 0x0F ], # "English Violet"
    [ 18.5, 0x04, 0x07, 0x0E ], # "Space Cadet"
    [ 19.0, 0x01, 0x03, 0x08 ], # "Maastricht Blue"
    [ 20.0, 0x01, 0x01, 0x06 ], # "Cetacean Blue"
    [ 24.0, 0x01, 0x01, 0x06 ], # "Cetacean Blue"
]

SKY_COLOR_XP = np.array([m[0] for m in SKY_COLOR_MAP])
R_SKY = np.array([m[1] for m in SKY_COLOR_MAP], dtype=np.uint8)
G_SKY = np.array([m[2] for m in SKY_COLOR_MAP], dtype=np.uint8)
B_SKY = np.array([m[3] for m in SKY_COLOR_MAP], dtype=np.uint8)

SUN_COLOR_MAP = [
    [  0.0, 0x00, 0x00, 0x00 ],
    [  6.5, 0x64, 0x00, 0x00 ],
    [  7.0, 0xBD, 0x24, 0x00 ],
    [  7.5, 0xD1, 0x76, 0x17 ],
    [  8.0, 0xD2, 0x9D, 0x6C ],
    [  8.5, 0xE7, 0xC7, 0xAA ],
    [ 15.5, 0xE7, 0xC7, 0xAA ],
    [ 17.0, 0xD2, 0x9D, 0x6C ],
    [ 17.4, 0xD1, 0x76, 0x17 ],
    [ 17.8, 0xBD, 0x24, 0x00 ],
    [ 18.2, 0x64, 0x00, 0x00 ],
    [ 24.0, 0x00, 0x00, 0x00 ],
]

SUN_COLOR_XP = np.array([m[0] for m in SUN_COLOR_MAP])
R_SUN = np.array([m[1] for m in SUN_COLOR_MAP], dtype=np.uint8)
G_SUN = np.array([m[2] for m in SUN_COLOR_MAP], dtype=np.uint8)
B_SUN = np.array([m[3] for m in SUN_COLOR_MAP], dtype=np.uint8)

SUN_POS_MAP = [
    [  0.0,  -LED_COUNT/2 ],
    [ 12.0,   LED_COUNT/2 ],
    [ 24.0, 3*LED_COUNT/2 ],
]

SUN_POS_XP = np.array([m[0] for m in SUN_POS_MAP])
SUN_POS = np.array([m[1] for m in SUN_POS_MAP])

SUN_RADIUS = 2.0

def add_args(parser):
    parser.set_defaults(init=init, render=render, set_args=set_args)

def set_args(args):
    pass

def init():
    pass

def render(frame, fb, fb_32):
    with wand.drawing.Drawing() as draw:
        current_time = (frame / 30) % 24
        
        b = int(round(np.interp(current_time, SKY_COLOR_XP, B_SKY)))
        g = int(round(np.interp(current_time, SKY_COLOR_XP, G_SKY)))
        r = int(round(np.interp(current_time, SKY_COLOR_XP, R_SKY)))

        bg = wand.color.Color(f"#{r:02x}{g:02x}{b:02x}")

        sun_pos = np.interp(current_time, SUN_POS_XP, SUN_POS)

        b = int(round(np.interp(current_time, SUN_COLOR_XP, B_SUN)))
        g = int(round(np.interp(current_time, SUN_COLOR_XP, G_SUN)))
        r = int(round(np.interp(current_time, SUN_COLOR_XP, R_SUN)))

        sun_fill = wand.color.Color(f"#{r:02x}{g:02x}{b:02x}")

        draw.fill_color = sun_fill
        draw.stroke_width = 0.5

        draw.ellipse((STRING_COUNT/2, sun_pos), [SUN_RADIUS, SUN_RADIUS*X_SCALE])
        #print(f"Sun at {sun_pos}, {STRING_COUNT/2} with radius {SUN_RADIUS}, {SUN_RADIUS*X_SCALE}")

        # ImageMagick exports data with rows as the primary index. We stream data to the
        # framebuffer columns-first to reduce the memory requirements of the FIFO. Rather
        # than generating the image and transposing, just generate a transposed image.
        with wand.image.Image(width=STRING_COUNT, height=LED_COUNT, background=bg) as img:
            draw(img)

            # Export pixels in framebuffer format
            pxl_list = img.export_pixels(channel_map='BRG', storage='char')
            interpolate_into(fb, pxl_list)