use std::cell::{RefMut};
use interpolation::Lerp;

use crate::constants;
use crate::animations::common::Renderable;

const COLOR_MAP_POINTS: usize = 3;

pub struct ColorPoint {
    val: f32,
    color: [u8; 3],
}

pub struct Waves {
    color_map: [ColorPoint; COLOR_MAP_POINTS],
    phase_params: [f32; 4],
}

impl Waves {
    pub fn new() -> Self {
        // Color format is framebuffer native, [B, G, R]
        let color_map = [
            ColorPoint {val:-1.0, color: [32,  0,  0] },
            ColorPoint {val: 0.0, color: [ 0, 32,  0] },
            ColorPoint {val: 1.0, color: [ 0,  0, 32] },
        ];

        let phase_params: [f32; 4] = [0.07, 0.03, 0.04, 0.01];

        Self {color_map, phase_params}
    }
}

fn dot(a: &[f32], b: &[f32]) -> f32 {
    return a.iter().zip(b.iter()).map(|(x, y)| x * y).sum();
}

impl Renderable for Waves {
    fn render(&mut self, frame: u32, fb: &mut RefMut<[u8]>) {

        // calculate phase at each point
        // This array is an LED_COUNT array of STRING_COUNT f32s. This is the
        // same order as the framebuffer.
        let mut color_index = [[0.0; constants::STRING_COUNT]; constants::LED_COUNT];
        for (x, row) in color_index.iter_mut().enumerate() {
            for (y, p) in row.iter_mut().enumerate() {
                *p = dot(&self.phase_params, &[frame as f32, x as f32, y as f32, (x*y) as f32]);
            }
        }

        // calculate sine of each phase
        for (_, row) in color_index.iter_mut().enumerate() {
            for (_, p) in row.iter_mut().enumerate() {
                *p = p.cos();
            }
        }

        // Interpolate into framebuffer

        /*
         * x is the longer coordinate here (LED_COUNT)
         * y is the shorter index (STRING_COUNT or string index)
         * 
         * if y is even, we go right into the framebuffer at (x, y/2)
         * if y is odd, we reverse and go into (LED_COUNT-1 - x, STRING_COUNT-1 - y/2)
         */

        for (x, row) in color_index.iter_mut().enumerate() {
            for (y, p) in row.iter_mut().enumerate() {
                let mut i = 0;
                // Find which pair of points this value falls between
                while i < COLOR_MAP_POINTS-2 && *p >= self.color_map[i+1].val {
                    i += 1;
                }
                // Scale the independent variable
                //print!("Using index {i}, original value is {p}\n");
                let alpha: f32 = (*p - self.color_map[i].val)/(self.color_map[i+1].val - self.color_map[i].val);
                // Perform the interpolation
                //print!("alpha = {alpha}\n");
                let color = self.color_map[i].color.lerp(&self.color_map[i+1].color, &alpha);

                //print!("{x},{y} {p} -> {color:?}\n");
                let idx = constants::fb_idx(x, y);
                fb[idx + 0] = color[0];
                fb[idx + 1] = color[1];
                fb[idx + 2] = color[2];
            }
        }

    }
}