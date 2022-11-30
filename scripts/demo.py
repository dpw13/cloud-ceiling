import mmap
import os
import numpy as np
import time

FPGA_REGS_BASE = 0x1000000
FPGA_REGS_SIZE = 0x2000

ID_REG = 0x0
SCRATCH_REG = 0x1
RESET_STATUS_REG = 0x2

FIFO_STATUS_REG = 0x8
FIFO_EMPTY_COUNT_REG = 0x9
HBLANK_REG = 0xA

FIFO_DATA_REGION = 0x1001000
FIFO_DATA_SIZE = 0x1000

LED_COUNT = 128
STRING_COUNT = 2
BYTES_PER_LED = 3

FRAME_SIZE = LED_COUNT*STRING_COUNT*BYTES_PER_LED
FRAME_WORDS = FRAME_SIZE >> 1

BLUE = 0
GREEN = 1
RED = 2

memmap = os.open("/dev/mem", os.O_RDWR)
regs_raw = mmap.mmap(memmap, length=FPGA_REGS_SIZE, offset=FPGA_REGS_BASE)
# Use numpy to access memory in 16-bit words
regs = np.frombuffer(regs_raw, np.uint16, FPGA_REGS_SIZE >> 1)

id_reg = regs[ID_REG]
print(f"Initialized. ID = 0x{id_reg:04x}")
empty = regs[FIFO_EMPTY_COUNT_REG]
print(f"Initial empty count is {empty}")

#regs[SCRATCH_REG] = 0x9999

fb_raw = mmap.mmap(memmap, length=FIFO_DATA_REGION, offset=FIFO_DATA_SIZE)
# Use numpy to access memory in individual bytes. Note that we only
# reserve the frame buffer itself.
fb = np.frombuffer(fb_raw, np.uint16, FRAME_WORDS)

fb_soft = np.zeros(FRAME_SIZE, dtype=np.uint8)
fb_soft_16 = np.frombuffer(fb_soft, np.uint16, FRAME_WORDS)

for i in range(0,8):
    for string_idx in range(0, STRING_COUNT):
        for led_idx in range(0, LED_COUNT):
            # Buffer format is (Pixel/String/Color)
            # 0/0/B, 0/0/R, 0/0/G, 0/1/B, 0/1/R, 0/1/G, ...
            # Base index of Pixel/String is 3*Y + STRING_COUNT*3*X = 3*(Y + STRING_COUNT*X)
            byte_idx = 3*(string_idx + STRING_COUNT*led_idx)

            if i % 4 == 0:
                fb_soft[byte_idx + BLUE] = 0xfe
                fb_soft[byte_idx + GREEN] = 0
                fb_soft[byte_idx + RED] = 0
            if i % 4 == 1:
                fb_soft[byte_idx + BLUE] = 0
                fb_soft[byte_idx + GREEN] = 0xfe
                fb_soft[byte_idx + RED] = 0
            if i % 4 == 2:
                fb_soft[byte_idx + BLUE] = 0
                fb_soft[byte_idx + GREEN] = 0
                fb_soft[byte_idx + RED] = 0xfe
            if i % 4 == 3:
                fb_soft[byte_idx + BLUE] = 0
                fb_soft[byte_idx + GREEN] = 0
                fb_soft[byte_idx + RED] = 0

    empty = regs[FIFO_EMPTY_COUNT_REG]
    print(f"Empty count before frame {i} is {empty}")

    for p in range(0, FRAME_WORDS):
        #print(f"Word {p} = 0x{fb_soft_16[p]:04x}")
        regs[0x800] = fb_soft_16[p]
    #np.copyto(fb, fb_soft_16, casting='no')

    empty = regs[FIFO_EMPTY_COUNT_REG]
    print(f"Empty count after frame {i} is {empty}")

    time.sleep(1)

os.close(memmap)