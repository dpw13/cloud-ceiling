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
    [   0.0, 0x01, 0x01, 0x06 ], # "Cetacean Blue"
    [  60.0, 0x01, 0x01, 0x06 ], # "Cetacean Blue"
    [  75.0, 0x01, 0x03, 0x08 ], # "Maastricht Blue"
    [  90.0, 0x07, 0x05, 0x0C ], # "Regalia"
    [  97.5, 0x10, 0x09, 0x0B ], # dusty rose
    [ 105.0, 0x13, 0x11, 0x0C ], # straw yellow
    [ 112.5, 0x17, 0x16, 0x13 ], # pale cream
    [ 120.0, 0x17, 0x18, 0x19 ], # light gray-blue
    [ 127.5, 0x19, 0x1D, 0x22 ], # medium blue
    [ 135.0, 0x0B, 0x26, 0x2F ], # medium blue
    [ 157.5, 0x04, 0x1F, 0x3D ], # deep day blue
    [ 225.0, 0x04, 0x1F, 0x3D ], # deep day blue
    [ 232.5, 0x0B, 0x26, 0x2F ], # medium blue
    [ 240.0, 0x1F, 0x1B, 0x0E ], # "Shandy"
    [ 255.0, 0x21, 0x14, 0x0B ], # "Sandy Brown"
    [ 270.0, 0x1C, 0x0A, 0x09 ], # "Sunset Orange"
    [ 277.5, 0x0C, 0x09, 0x0F ], # "English Violet"
    [ 285.0, 0x04, 0x07, 0x0E ], # "Space Cadet"
    [ 300.0, 0x01, 0x01, 0x06 ], # "Cetacean Blue"
    [ 360.0, 0x01, 0x01, 0x06 ], # "Cetacean Blue"
]

SKY_COLOR_XP = np.array([m[0] for m in SKY_COLOR_MAP])
R_SKY = np.array([m[1] for m in SKY_COLOR_MAP], dtype=np.uint8)
G_SKY = np.array([m[2] for m in SKY_COLOR_MAP], dtype=np.uint8)
B_SKY = np.array([m[3] for m in SKY_COLOR_MAP], dtype=np.uint8)

SUN_COLOR_MAP = [
    [   0.0, 0x00, 0x00, 0x00 ],
    [  90.0, 0x64, 0x00, 0x00 ],
    [ 105.0, 0xBD, 0x24, 0x00 ],
    [ 112.5, 0xD1, 0x76, 0x17 ],
    [ 120.0, 0xD2, 0x9D, 0x6C ],
    [ 127.5, 0xE7, 0xC7, 0xAA ],
    [ 232.5, 0xE7, 0xC7, 0xAA ],
    [ 255.0, 0xD2, 0x9D, 0x6C ],
    [ 261.0, 0xD1, 0x76, 0x17 ],
    [ 267.0, 0xBD, 0x24, 0x00 ],
    [ 270.0, 0x64, 0x00, 0x00 ],
    [ 360.0, 0x00, 0x00, 0x00 ],
]

SUN_COLOR_XP = np.array([m[0] for m in SUN_COLOR_MAP])
R_SUN = np.array([m[1] for m in SUN_COLOR_MAP], dtype=np.uint8)
G_SUN = np.array([m[2] for m in SUN_COLOR_MAP], dtype=np.uint8)
B_SUN = np.array([m[3] for m in SUN_COLOR_MAP], dtype=np.uint8)

POS_MAP = [
    [   0.0,  -LED_COUNT/2 ],
    [ 180.0,   LED_COUNT/2 ],
    [ 360.0, 3*LED_COUNT/2 ],
]

POS_XP = np.array([m[0] for m in POS_MAP])
POS = np.array([m[1] for m in POS_MAP])

SUN_RADIUS = 2.0

MOON_COLOR_MAP = [
    [   0.0, 0x00, 0x00, 0x00 ],
    [  90.0, 0x17, 0x16, 0x13 ],
    [ 105.0, 0x22, 0x22, 0x1D ],
    [ 120.0, 0x2B, 0x2B, 0x2B ],
    [ 240.0, 0x2B, 0x2B, 0x2B ],
    [ 255.0, 0x22, 0x22, 0x1D ],
    [ 270.0, 0x17, 0x16, 0x13 ],
    [ 360.0, 0x00, 0x00, 0x00 ],
]

MOON_COLOR_XP = np.array([m[0] for m in MOON_COLOR_MAP])
R_MOON = np.array([m[1] for m in MOON_COLOR_MAP], dtype=np.uint8)
G_MOON = np.array([m[2] for m in MOON_COLOR_MAP], dtype=np.uint8)
B_MOON = np.array([m[3] for m in MOON_COLOR_MAP], dtype=np.uint8)

MOON_SPEED_RATE = 0.9661016949152542
MOON_RADIUS = 2.0

def add_args(parser):
    parser.set_defaults(init=init, render=render, set_args=set_args)

def set_args(args):
    pass

def init():
    pass

def render(frame, fb, fb_32):
    with wand.drawing.Drawing() as draw:
        sun_angle = (frame / 2) % 360
        
        b = int(round(np.interp(sun_angle, SKY_COLOR_XP, B_SKY)))
        g = int(round(np.interp(sun_angle, SKY_COLOR_XP, G_SKY)))
        r = int(round(np.interp(sun_angle, SKY_COLOR_XP, R_SKY)))

        bg = wand.color.Color(f"#{r:02x}{g:02x}{b:02x}")

        sun_pos = np.interp(sun_angle, POS_XP, POS)

        b = int(round(np.interp(sun_angle, SUN_COLOR_XP, B_SUN)))
        g = int(round(np.interp(sun_angle, SUN_COLOR_XP, G_SUN)))
        r = int(round(np.interp(sun_angle, SUN_COLOR_XP, R_SUN)))

        sun_fill = wand.color.Color(f"#{r:02x}{g:02x}{b:02x}")

        draw.fill_color = sun_fill
        draw.stroke_width = 0.5

        draw.ellipse((STRING_COUNT/2, sun_pos), [SUN_RADIUS, SUN_RADIUS*X_SCALE])

        moon_angle = (frame / 2.07 + 125) % 360
        moon_pos = np.interp(moon_angle, POS_XP, POS)

        b = int(round(np.interp(moon_angle, MOON_COLOR_XP, B_MOON)))
        g = int(round(np.interp(moon_angle, MOON_COLOR_XP, G_MOON)))
        r = int(round(np.interp(moon_angle, MOON_COLOR_XP, R_MOON)))

        moon_fill = wand.color.Color(f"#{r:02x}{g:02x}{b:02x}")

        draw.fill_color = moon_fill
        draw.stroke_width = 0.5

        draw.ellipse((STRING_COUNT/2, moon_pos), [SUN_RADIUS, SUN_RADIUS*X_SCALE])

        # ImageMagick exports data with rows as the primary index. We stream data to the
        # framebuffer columns-first to reduce the memory requirements of the FIFO. Rather
        # than generating the image and transposing, just generate a transposed image.
        with wand.image.Image(width=STRING_COUNT, height=LED_COUNT, background=bg) as img:
            draw(img)

            # Export pixels in framebuffer format
            pxl_list = img.export_pixels(channel_map='BRG', storage='char')
            interpolate_into(fb, pxl_list)
