from constants import *

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

def interpolate_into(fb, pxl_list):
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
