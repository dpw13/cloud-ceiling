use std::time::{Duration, Instant};
use std::thread::sleep;

use magick_rust::{magick_wand_genesis, DrawingWand, PixelWand, MagickWand};

mod led_lib;
use led_lib::constants;
use led_lib::led_display;

fn main() {
    // Initialize magick-wand
    magick_wand_genesis();

    let disp = led_display::LedDisplay::new();
    let id = disp.read_id();

    println!("FPGA ID: 0x{:x}", id);
    println!("Starting empty count: {}", disp.empty_count());

    let mut mut_fb = disp.fb_cell.borrow_mut();
    let fb = mut_fb.get_mut(0..constants::FRAME_SIZE_BYTES)
              .expect("Could not get framebuffer slice");

    let mut wand = MagickWand::new();
    let mut draw = DrawingWand::new();

    let mut bg = PixelWand::new();
    bg.set_color("rgb(0,0,0)").expect("Could not set color");

    let mut draw_time = Duration::from_millis(0);
    let mut render_time = Duration::from_millis(0);
    let mut copy_time = Duration::from_millis(0);

    let now = Instant::now();
    for frame in 0..100 {
        let r = (frame + 0) % 24;
        let b = (frame + 8) % 24;
        let g = (frame + 16) % 24;
        let color_str = format!("rgb({},{},{})", r, b, g);
        bg.set_color(&color_str).expect("Could not set color");

        // Create new image. There isn't a good way to clear the existing image, so just create a new one.
        wand.new_image(
            constants::STRING_COUNT as usize,
            constants::LED_COUNT as usize,
            &bg)
            .expect("Could create new image");

        // the `clear` methods are marked private. We do this ugly hack to call the actual
        // bound clear function on the internal struct (which fortunately is public).
        unsafe {magick_rust::bindings::ClearDrawingWand(draw.wand)};

        // Drawing code here
        draw.set_fill_color(&bg);
        draw.draw_rectangle(0.0, 0.0, 1.0, 1.0);

        // Make sure the last flush is really going through
        disp.empty_count();

        // Render
        let draw_start = Instant::now();
        wand.draw_image(&draw).expect("Could not draw image");

        disp.empty_count();

        // Export pixels in framebuffer format
        let export_start = Instant::now();
        let img_data = wand.export_image_pixels(0, 0, 
            constants::STRING_COUNT as usize, 
            constants::LED_COUNT as usize, "BRG")
            .expect("Could not export pixels");
        disp.empty_count();

        let copy_start = Instant::now();
        // Copy to kernel buffer
        fb.copy_from_slice(&img_data);
        let copy_end = Instant::now();

        draw_time += export_start - draw_start;
        render_time += copy_start - export_start;
        copy_time += copy_end - copy_start;

        // Call ioctl to DMA to hardware
        disp.flush();

        // Cleanup before next frame
        unsafe {magick_rust::bindings::MagickRemoveImage(wand.wand)};
    }

    println!("100 frames in {:?}. Spent {:?} in flush.", now.elapsed(), disp.wait_time.get());
    println!("Spent {:?} in draw, {:?} in export, {:?} in copy", draw_time, render_time, copy_time);

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
