#
# Weather simulation
#

from constants import *
import numpy as np
import wand.image
import wand.drawing

SKY_BG_MAP = [
    # Format:
    # [ age, r, g, b ]
    [  0.0, 0x01, 0x01, 0x06 ], # "Cetacean Blue"
    [  6.0, 0x01, 0x02, 0x09 ],
    [  6.5, 0x07, 0x05, 0x0C ], # "Regalia"
    [  7.0, 0x10, 0x09, 0x0B ], # dusty rose
    [  7.5, 0x13, 0x11, 0x0C ], # straw yellow
    [  8.0, 0x17, 0x16, 0x13 ], # pale cream
    [  8.5, 0x17, 0x18, 0x19 ], # light gray-blue
    [  9.0, 0x19, 0x1D, 0x22 ], # medium blue
    [ 10.0, 0x0B, 0x26, 0x2F ], # medium blue
    [ 10.5, 0x04, 0x1F, 0x3D ], # deep day blue
    [ 16.5, 0x04, 0x1F, 0x3D ], # deep day blue
    [ 17.0, 0x0B, 0x26, 0x2F ], # medium blue
    [ 17.5, 0x1F, 0x1B, 0x0E ], # "Shandy"
    [ 18.0, 0x21, 0x14, 0x0B ], # "Sandy Brown"
    [ 18.5, 0x1C, 0x0A, 0x09 ], # "Sunset Orange"
    [ 19.0, 0x0C, 0x09, 0x0F ], # "English Violet"
    [ 19.5, 0x04, 0x07, 0x0E ], # "Space Cadet"
    [ 20.0, 0x01, 0x03, 0x08 ], # "Maastricht Blue"
    [ 21.0, 0x01, 0x01, 0x06 ], # "Cetacean Blue"
    [ 24.0, 0x01, 0x01, 0x06 ], # "Cetacean Blue"
]

TIME_XP = np.array([m[0] for m in SKY_BG_MAP])
R_BG = np.array([m[1] for m in SKY_BG_MAP], dtype=np.uint8)
G_BG = np.array([m[2] for m in SKY_BG_MAP], dtype=np.uint8)
B_BG = np.array([m[3] for m in SKY_BG_MAP], dtype=np.uint8)

def add_args(parser):
    parser.set_defaults(init=init, render=render, set_args=set_args)

def set_args(args):
    pass

def init():
    pass

def render(frame, fb, fb_32):
    with wand.drawing.Drawing() as draw:
        current_time = (frame / 60) % 24
        
        b = int(round(np.interp(current_time, TIME_XP, B_BG)))
        g = int(round(np.interp(current_time, TIME_XP, G_BG)))
        r = int(round(np.interp(current_time, TIME_XP, R_BG)))

        bg = wand.color.Color(f"#{r:02x}{g:02x}{b:02x}")

        # ImageMagick exports data with rows as the primary index. We stream data to the
        # framebuffer columns-first to reduce the memory requirements of the FIFO. Rather
        # than generating the image and transposing, just generate a transposed image.
        with wand.image.Image(width=STRING_COUNT, height=LED_COUNT, background=bg) as img:
            # Export pixels in framebuffer format
            pxl_list = img.export_pixels(channel_map='BRG', storage='char')
            # Copy to framebuffer. Ideally this additional copy wouldn't be necessary
            # export_pixels returns a list of int32 and our destination buffer is a list of u8
            np.copyto(fb, pxl_list, casting='unsafe')
