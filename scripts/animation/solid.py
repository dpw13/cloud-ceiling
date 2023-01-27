#
# Solid color. No animation
#

from constants import *
import numpy as np
import wand.image
import wand.drawing

BG = wand.color.Color('black')

def add_args(parser):
    parser.add_argument('--red', '-r', type=int, default=0)
    parser.add_argument('--blue', '-b', type=int, default=0)
    parser.add_argument('--green', '-g', type=int, default=0)
    parser.set_defaults(init=init, render=render, set_args=set_args)

def set_args(args):
    global BG
    color_str = f"rgb({args.red},{args.blue},{args.green})"
    print(f"Setting color to {color_str}")
    BG = wand.color.Color(f"rgb({args.red},{args.blue},{args.green})")

def init():
    pass

def render(frame, fb, fb_32):
    with wand.drawing.Drawing() as draw:
        # ImageMagick exports data with rows as the primary index. We stream data to the
        # framebuffer columns-first to reduce the memory requirements of the FIFO. Rather
        # than generating the image and transposing, just generate a transposed image.
        with wand.image.Image(width=STRING_COUNT, height=LED_COUNT, background=BG) as img:
            # Export pixels in framebuffer format
            pxl_list = img.export_pixels(channel_map='BRG', storage='char')
            # Copy to framebuffer. Ideally this additional copy wouldn't be necessary
            # export_pixels returns a list of int32 and our destination buffer is a list of u8
            np.copyto(fb, pxl_list, casting='unsafe')
