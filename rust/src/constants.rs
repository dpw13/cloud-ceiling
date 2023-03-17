
pub const FPGA_REGS_BASE: u64 = 0x1000000;
pub const FPGA_REGS_SIZE: usize = 0x2000;
pub const FIFO_DATA_SIZE: usize = 0x4000;

/* Needs to match FPGA to get correct framebuffer size. */
pub const LED_COUNT: u32 = 118;
pub const STRING_COUNT: u32 = 24;
pub const BYTES_PER_LED: u32 = 3;

pub const FRAME_SIZE_BYTES: usize = (LED_COUNT*STRING_COUNT*BYTES_PER_LED) as usize;
pub const FRAME_SIZE_WORDS: usize = FRAME_SIZE_BYTES / 2;
