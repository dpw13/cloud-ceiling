import mmap
import os
import numpy as np
import time
import fcntl

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
STRING_COUNT = 4
BYTES_PER_LED = 3

FRAME_SIZE = LED_COUNT*STRING_COUNT*BYTES_PER_LED
FRAME_WORDS = FRAME_SIZE >> 2

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

ledfb_fd = os.open("/dev/ledfb", os.O_RDWR)
fb_raw = mmap.mmap(ledfb_fd, length=FRAME_SIZE, offset=0)
# Use numpy to access memory in individual bytes. Note that we only
# reserve the frame buffer itself.
fb = np.frombuffer(fb_raw, np.uint8, FRAME_SIZE)
fb_32 = np.frombuffer(fb, np.uint32, FRAME_WORDS)

for frame in range(0, 16):
    #print("Filling")
    fb_32.fill(0)
    for string_idx in range(0, STRING_COUNT):
        for led_idx in range(0, LED_COUNT):
            # Buffer format is (Pixel/String/Color)
            # 0/0/B, 0/0/R, 0/0/G, 0/1/B, 0/1/R, 0/1/G, ...
            # Base index of Pixel/String is 3*Y + STRING_COUNT*3*X = 3*(Y + STRING_COUNT*X)
            if (led_idx + string_idx + 4*frame) % 8 == 0:
                byte_idx = 3*(string_idx + STRING_COUNT*led_idx)

                fb[byte_idx + BLUE] = 0x20
                fb[byte_idx + GREEN] = 0x20
                fb[byte_idx + RED] = 0x20

    empty = regs[FIFO_EMPTY_COUNT_REG]
    while (empty < 2048):
        time.sleep(0.001)
        empty = regs[FIFO_EMPTY_COUNT_REG]
    #print(f"Empty count before frame {frame} is {empty}")

    fcntl.ioctl(ledfb_fd, 0, FRAME_SIZE)
    time.sleep(0.004)
    status = regs[FIFO_STATUS_REG]

time.sleep(0.1)

# Turn off LEDs
fb_32.fill(0)
fcntl.ioctl(ledfb_fd, 0, FRAME_SIZE)
time.sleep(0.004)
status = regs[FIFO_STATUS_REG]
empty = regs[FIFO_EMPTY_COUNT_REG]

print(f"FIFO status: 0x{status:04x} empty: {empty}")

fb_raw.close()
os.close(ledfb_fd)
regs_raw.close()
os.close(memmap)