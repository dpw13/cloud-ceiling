use std::cell::{RefMut};
use std::time::{Duration, Instant};
use std::thread::sleep;

use magick_rust::{magick_wand_genesis};

use animations::strobe::Strobe;
use animations::waves::Waves;
use animations::common::Renderable;
use display::LedDisplay;

mod constants;
mod display;
mod animations;

fn render<T: Renderable>(frame: u32, fb: &mut RefMut<[u8]>, anim: &mut T) {
    anim.render(frame, fb);
}

fn main() {
    // Initialize magick-wand
    magick_wand_genesis();

    let disp = LedDisplay::new();
    let id = disp.read_id();

    println!("FPGA ID: 0x{:x}", id);
    println!("Starting empty count: {}", disp.empty_count());

    let mut fb = disp.borrow_fb();
    fb.fill(0);

    // Config
    let frame_cnt = 10000;

    let mut anim = Waves::new();

    let now = Instant::now();

    for frame in 0..frame_cnt {
        render(frame as u32, &mut fb, &mut anim);
        // Call ioctl to DMA to hardware
        disp.flush();
    }

    println!("{framecnt} frames in {:?}. Spent {:?} in flush.", now.elapsed(), disp.wait_time.get());

    // Blank
    fb.fill(0);
    disp.flush();
    // Wait for DMA to finish. Otherwise the last blank frame doesn't get flushed.
    sleep(Duration::from_millis(5));

    while disp.empty_count() < 8000 {
        sleep(Duration::from_micros(100));
    }
    println!("Ending empty count: {}", disp.empty_count());
}
