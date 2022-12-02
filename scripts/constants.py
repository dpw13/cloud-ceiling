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

LED_COUNT = 150
STRING_COUNT = 4
BYTES_PER_LED = 3

FRAME_SIZE = LED_COUNT*STRING_COUNT*BYTES_PER_LED
FRAME_WORDS = FRAME_SIZE >> 2

BLUE = 0
GREEN = 1
RED = 2
