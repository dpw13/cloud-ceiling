FPGA_REGS_BASE = 0x1000000
FPGA_REGS_SIZE = 0x2000

ID_REG = 0x0
SCRATCH_REG = 0x1
RESET_STATUS_REG = 0x2

FIFO_STATUS_REG = 0x8
FIFO_EMPTY_COUNT_REG = 0x9

MIC_LED_DATA_REG = 0xc
MIC_LED_COUNT = 12

FIFO_DATA_REGION = 0x1001000
FIFO_DATA_SIZE = 0x4000

# Needs to match FPGA to get correct framebuffer size.
LED_COUNT = 118
STRING_COUNT = 24
BYTES_PER_LED = 3

FRAME_SIZE = LED_COUNT*STRING_COUNT*BYTES_PER_LED
FRAME_WORDS = FRAME_SIZE >> 2

BLUE = 0
RED = 1
GREEN = 2

# The ratio of Y distance to X distance. Multiply X axes by this to square up images
X_SCALE = 2.15
