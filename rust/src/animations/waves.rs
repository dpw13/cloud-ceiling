//use rand::prelude::*;
use fastrand;
use std::cell::{RefMut};
use interpolation::Lerp;

use clap::{ValueEnum, Args};

use crate::constants;
use crate::animations::common::Renderable;

#[derive(Args)]
pub struct WaveArgs {
    #[arg(short, long, default_value_t = ColorMap::Rainbow)]
    color_map: ColorMap,

    #[arg(short, long, default_value_t = -0.15)]
    frame_coeff: f32,
    #[arg(short, long, default_value_t = 0.0)]
    x_coeff: f32,
    #[arg(short, long, default_value_t = 0.0)]
    y_coeff: f32,
    #[arg(short, long, default_value_t = 0.20)]
    r_coeff: f32,

    #[arg(long, default_value_t = 59.0)]
    x_off: f32,
    #[arg(long, default_value_t = 12.0)]
    y_off: f32,
}

#[derive(ValueEnum, Clone, Debug, PartialEq, Eq)]
enum ColorMap {
    Rainbow,
    Elite,
    Sky,
}

impl std::fmt::Display for ColorMap {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        self.to_possible_value()
            .expect("no values are skipped")
            .get_name()
            .fmt(f)
    }
}

pub struct ColorPoint {
    val: f32,
    color: [u8; 3],
}

struct Wander {
    accel_to_ctr: f32,
    temp: f32,
    decel: f32,

    bound_ctr: f32,
    bound_radius: f32,

    // Position and velocity are always for a 2x2 box centered at the origin
    pos: f32,
    vel: f32,
    accel: f32,
}

fn rand_range(min: f32, max: f32) -> f32 {
    fastrand::f32() * (max-min) + min
}

impl Wander {
    fn new(min: f32, max: f32, val: f32) -> Self {
        let width = max - min;
        let pos = val/width + min;

        Self {
            accel_to_ctr: 0.01,
            temp: 0.003,
            decel: 0.9,
            bound_ctr: (min + max)/2.0,
            bound_radius: width/2.0,
            pos,
            vel: 0.0,
            accel: 0.0,
        }
    }

    fn step_accel(&mut self) {
        /*
         * Velocity change consists of:
         * - deceleration towards stopped
         * - acceleration towards center
         * - random impulse
         */
        self.accel = self.decel * self.accel + rand_range(-self.temp, self.temp);
    }

    fn step(&mut self) {
        self.vel =
            -self.accel_to_ctr * self.pos.powi(5) +
            self.accel;

        self.pos += self.vel;
    }

    fn get_pos(&self) -> f32 {
        self.bound_radius * self.pos + self.bound_ctr
    }
}

struct WanderN {
    wanderers : Vec<Wander>
}

impl WanderN {
    fn new(dim : usize, min: &[f32], max: &[f32], val: &[f32]) -> Self {
        let mut wanderers = Vec::<Wander>::new();

        for i in 0..dim {
            wanderers.push(Wander::new(min[i], max[i], val[i]));
        }

        WanderN {wanderers}
    }

    fn step_accel(&mut self) {
        self.wanderers.iter_mut().for_each(|w| w.step_accel());
    }

    fn step(&mut self) {
        self.wanderers.iter_mut().for_each(|w| w.step());
    }

    fn get_pos(&self) -> Vec<f32> {
        self.wanderers.iter().map(|w| w.get_pos()).collect()
    }
}

pub struct Waves {
    color_map: Box<[ColorPoint]>,
    phase_coeffs: WanderN,
    phase_offsets: WanderN,
}

impl Waves {
    pub fn new(args: WaveArgs) -> Self {
        // Color format is framebuffer native, [B, R, G]
        let color_map: Box<[ColorPoint]>;

        match args.color_map {
            ColorMap::Rainbow => {
                color_map = Box::new([
                    ColorPoint {val:-1.00001, color: [32,  0,  0] },
                    ColorPoint {val:-0.70000, color: [16, 16,  0] },
                    ColorPoint {val: 0.00000, color: [ 0, 32,  0] },
                    ColorPoint {val: 0.70000, color: [ 0, 16, 16] },
                    ColorPoint {val: 1.00001, color: [ 0,  0, 32] },
                ]);
            }
            ColorMap::Elite => {
                color_map = Box::new([
                    ColorPoint {val:-1.00001, color: [ 0,  0,  0] },
                    ColorPoint {val: 0.20000, color: [ 0,  0,  0] },
                    ColorPoint {val: 1.00001, color: [ 0, 24,  4] },
                ]);
            }
            ColorMap::Sky => {
                color_map = Box::new([
                    ColorPoint {val:-1.00001, color: [24,  0,  0] },
                    ColorPoint {val:-0.80001, color: [24,  0,  0] },
                    ColorPoint {val:-0.40001, color: [16, 16, 16] },
                    ColorPoint {val: 0.50000, color: [ 4,  4,  4] },
                    ColorPoint {val: 1.00001, color: [ 1,  1,  1] },
                ]);
            }
        }

        let phase_coeff_start = [args.frame_coeff, args.x_coeff, args.y_coeff, args.r_coeff];
        let phase_coeffs = WanderN::new(4, &[-0.3; 4], &[0.3; 4], &phase_coeff_start);

        let phase_offset_start = [rand_range(0.0, constants::LED_COUNT as f32), rand_range(0.0, constants::STRING_COUNT as f32)];
        let phase_offsets = WanderN::new(2, &[0.0; 2], &[constants::LED_COUNT as f32, constants::STRING_COUNT as f32], &phase_offset_start);

        Self {color_map, phase_coeffs, phase_offsets}
    }
}

fn dot(a: &[f32], b: &[f32]) -> f32 {
    return a.iter().zip(b.iter()).map(|(x, y)| x * y).sum();
}

impl Renderable for Waves {
    fn render(&mut self, frame: u32, fb: &mut RefMut<[u8]>) {
        let frame_f32 = frame as f32;
        if frame % 20 == 0 {
            self.phase_offsets.step_accel();
        }
        self.phase_offsets.step();

        // calculate phase at each point
        // This array is an LED_COUNT array of STRING_COUNT f32s. This is the
        // same order as the framebuffer.
        let mut color_index = [[0.0; constants::STRING_COUNT]; constants::LED_COUNT];
        let phase_offset = self.phase_offsets.get_pos();
        let phase_coeff = self.phase_coeffs.get_pos();
        for (x, row) in color_index.iter_mut().enumerate() {
            let xo = constants::X_SCALE*(x as f32 - phase_offset[0]);
            let xo2 = xo.powi(2);
            for (y, p) in row.iter_mut().enumerate() {
                let yo = y as f32 - phase_offset[1];
                let r = f32::sqrt(xo2 + yo.powi(2));
                //print!("{x},{y} rsq = {rsq}\n");

                *p = dot(&phase_coeff, &[frame_f32, xo, yo, r]);
            }
        }

        // calculate cosine of each phase, mapping an arbitrary f32 onto [-1.0, 1.0]
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
                // Find which pair of points this value falls between
                //print!("{x},{y} {p}\n");
                let i = self.color_map.iter().position(|x| *p <= x.val).expect("{p} is outside of map limits") - 1;

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