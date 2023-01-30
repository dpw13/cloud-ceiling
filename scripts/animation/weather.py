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
    [  0.0, 0x07, 0x0B, 0x34 ], # "Cetacean Blue"
    [  4.0, 0x07, 0x0B, 0x34 ],
    [  6.0, 0x48, 0x34, 0x75 ], # "Regalia"
    [  7.0, 0xD7, 0x79, 0x8B ], # dusty rose
    [  8.0, 0xFE, 0xE1, 0x97 ], # straw yellow
    [  8.5, 0xF3, 0xEC, 0xD0 ], # pale cream
    [  9.0, 0xC6, 0xD0, 0xDE ], # light gray-blue
    [  9.5, 0x90, 0xA7, 0xC4 ], # medium blue
    [ 10.0, 0x6B, 0xCF, 0xFF ], # medium blue
    [ 11.0, 0x00, 0xAD, 0xFF ], # deep day blue
    [ 16.0, 0x6B, 0xCF, 0xFF ], # medium blue
    [ 17.0, 0xFF, 0xE3, 0x73 ], # "Shandy"
    [ 18.0, 0xFC, 0x9C, 0x54 ], # "Sandy Brown"
    [ 18.5, 0xFD, 0x5E, 0x53 ], # "Sunset Orange"
    [ 19.0, 0x4B, 0x3D, 0x60 ], # "English Violet"
    [ 20.0, 0x15, 0x28, 0x52 ], # "Space Cadet"
    [ 21.0, 0x08, 0x18, 0x3A ], # "Maastricht Blue"
    [ 24.0, 0x07, 0x0B, 0x34 ], # "Cetacean Blue"
]

TIME_XP = np.array([m[0] for m in SKY_BG_MAP])
B_BG = np.array([m[1] for m in SKY_BG_MAP], dtype=np.uint8)
G_BG = np.array([m[2] for m in SKY_BG_MAP], dtype=np.uint8)
R_BG = np.array([m[3] for m in SKY_BG_MAP], dtype=np.uint8)

def add_args(parser):
    parser.set_defaults(init=init, render=render, set_args=set_args)

def set_args(args):
    pass

def init():
    pass

def render(frame, fb, fb_32):
    with wand.drawing.Drawing() as draw:
        current_time = (frame / 6) % 24
        
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
