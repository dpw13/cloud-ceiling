pub const FPGA_REGS_BASE: u64 = 0x1000000;
pub const FPGA_REGS_SIZE: usize = 0x2000;
pub const FIFO_DATA_SIZE: usize = 0x4000;

/* Needs to match FPGA to get correct framebuffer size. */
pub const LED_COUNT: usize = 118;
pub const STRING_COUNT: usize = 46;
pub const PIXEL_COUNT: usize = LED_COUNT * STRING_COUNT;
pub const BYTES_PER_LED: usize = 3;

pub const FRAME_SIZE_BYTES: usize = (PIXEL_COUNT * BYTES_PER_LED) as usize;
pub const FRAME_SIZE_WORDS: usize = FRAME_SIZE_BYTES / 2;

// The ratio of Y distance to X distance. Multiply X axes by this to square up images
pub const X_SCALE: f32 = 1.0 / 2.15;
/*
 * This returns the base index of the first color associated with these
 * logical position in the image.
 * x is higher towards the door, y is higher towards the garage (?)
 * x in [0:LED_COUNT), y in [0:STRING_COUNT)
 *
 * The framebuffer is actually LED_COUNT*2 rows of STRING_COUNT/2 pixels
 */
pub fn fb_idx(x: usize, y: usize) -> usize {
    let y_fb = y / 2;

    let x_fb: usize;

    if y % 2 == 0 {
        x_fb = x;
    } else {
        x_fb = 2 * LED_COUNT - 1 - x;
    }
    let fb_idx = (y_fb + x_fb * STRING_COUNT / 2) * BYTES_PER_LED;
    //print!("-> {x_fb},{y_fb} = {fb_idx}\n");

    fb_idx
}
