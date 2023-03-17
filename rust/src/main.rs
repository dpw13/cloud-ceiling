use std::time::{Duration, Instant};
use std::thread::sleep;

use magick_rust::{magick_wand_genesis};

use animations::strobe::Strobe;
use animations::common::Renderable;
use led_lib::LedDisplay;

mod constants;
mod led_lib;
mod animations;

fn main() {
    // Initialize magick-wand
    magick_wand_genesis();

    let disp = LedDisplay::new();
    let id = disp.read_id();

    println!("FPGA ID: 0x{:x}", id);
    println!("Starting empty count: {}", disp.empty_count());

    let mut mut_fb = disp.fb_cell.borrow_mut();
    let fb = mut_fb.get_mut(0..constants::FRAME_SIZE_BYTES)
              .expect("Could not get framebuffer slice");

    let mut anim = Strobe::new();

    let now = Instant::now();
    for frame in 0..100 {
        anim.render(frame, fb);

        // Call ioctl to DMA to hardware
        disp.flush();
    }

    println!("100 frames in {:?}. Spent {:?} in flush.", now.elapsed(), disp.wait_time.get());

    // Blank
    mut_fb.fill(0);
    disp.flush();
    // Wait for DMA to finish. Otherwise the last blank frame doesn't get flushed.
    sleep(Duration::from_millis(5));

    while disp.empty_count() < 8000 {
        sleep(Duration::from_micros(100));
    }
    println!("Ending empty count: {}", disp.empty_count());
}
