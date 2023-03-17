use magick_rust::{DrawingWand, PixelWand, MagickWand};

use crate::constants;
use crate::animations::common::Renderable;

pub struct Strobe {
    wand: MagickWand,
    draw: DrawingWand,
    bg: PixelWand,
}

impl Strobe {
    pub fn new() -> Self {
        let wand = MagickWand::new();
        let draw = DrawingWand::new();
        let mut bg = PixelWand::new();
        bg.set_color("rgb(0,0,0)").expect("Could not set color");

        Strobe {wand, draw, bg}
    }

    fn prepare(&mut self) {
        // Create new image. There isn't a good way to clear the existing image, so just create a new one.
        self.wand.new_image(
            constants::STRING_COUNT as usize,
            constants::LED_COUNT as usize,
            &self.bg)
            .expect("Could create new image");

        // the `clear` methods are marked private. We do this ugly hack to call the actual
        // bound clear function on the internal struct (which fortunately is public).
        unsafe {magick_rust::bindings::ClearDrawingWand(self.draw.wand)};
    }

    fn cleanup(&mut self) {
        // Cleanup before next frame
        unsafe {magick_rust::bindings::MagickRemoveImage(self.wand.wand)};
    }
}

impl Renderable for Strobe {
    fn render(&mut self, frame: i32, fb: &mut [u8]) {
        self.prepare();

        let r = (frame + 0) % 24;
        let b = (frame + 8) % 24;
        let g = (frame + 16) % 24;
        let color_str = format!("rgb({},{},{})", r, b, g);
        self.bg.set_color(&color_str).expect("Could not set color");

        // Drawing code here
        self.draw.set_fill_color(&self.bg);
        self.draw.draw_rectangle(0.0, 0.0, 1.0, 1.0);

        // Render
        self.wand.draw_image(&self.draw).expect("Could not draw image");

        // Export pixels in framebuffer format
        let img_data = self.wand.export_image_pixels(0, 0, 
            constants::STRING_COUNT as usize, 
            constants::LED_COUNT as usize, "BRG")
            .expect("Could not export pixels");

        // Copy to kernel buffer
        fb.copy_from_slice(&img_data);

        self.cleanup();
    }
}