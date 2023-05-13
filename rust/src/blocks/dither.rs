use json::JsonValue;
use num_traits::{clamp, Pow};
//use rand::Rng;

use crate::render_block::{RenderState, RenderBlock};
use crate::var_types::{Color};

pub struct Dither {
    // Params
    dither_add: Box<[f32]>,
    gamma: f32,
    // color coefficients
    rc: f32,
    gc: f32,
    bc: f32,

    // Inputs
    scale_idx: usize,
    i_idx: usize,

    x_idx: usize,
    y_idx: usize,

    // Outputs
    o_idx: usize,
}

impl Dither {
    pub fn from_obj(dict: &json::object::Object) -> Self {
        let input_obj = match dict.get("params").expect("Missing params definition") {
            JsonValue::Object(x) => x,
            _ => panic!("Initialization for Dither params is not an object"),
        };
        let gamma = input_obj.get("gamma").expect("Missing gamma input").as_f32().expect("Could not parse gamma input");
        let rc = input_obj.get("rc").expect("Missing R coefficient input").as_f32().expect("Could not parse R coefficient input");
        let gc = input_obj.get("gc").expect("Missing G coefficient input").as_f32().expect("Could not parse G coefficient input");
        let bc = input_obj.get("bc").expect("Missing B coefficient input").as_f32().expect("Could not parse B coefficient input");

        let input_obj = match dict.get("inputs").expect("Missing input definition") {
            JsonValue::Object(x) => x,
            _ => panic!("Initialization for Dither inputs is not an object"),
        };

        let scale_idx = input_obj.get("scale").expect("Missing scale input").as_usize().expect("Could not parse scale input");
        let i_idx = input_obj.get("i").expect("Missing i input").as_usize().expect("Could not parse i input");
        let x_idx = input_obj.get("x").expect("Missing x input").as_usize().expect("Could not parse x input");
        let y_idx = input_obj.get("y").expect("Missing y input").as_usize().expect("Could not parse y input");

        let output_obj = match dict.get("outputs").expect("Missing output definition") {
            JsonValue::Object(x) => x,
            _ => panic!("Initialization for Dither outputs is not an object"),
        };

        let o_idx = output_obj.get("o").expect("Missing o output").as_usize().expect("Could not parse o output");

        /*
         * dither adders for period 2:
         * [0.0 0.5]
         * 
         * for period 4:
         * [0.0 0.5 0.25 0.75]
         * [00 10 01 11] - bit reversal?
         * 
         * for period 8:
         * [000 001 010 011 100 101 110 111]
         * [000 100 010 110 001 101 011 111]
         * [0/8 4/8 2/8 6/8 1/8 5/8 3/8 7/8]
         * [0.0 0.5 0.25 0.75 0.125 0.625 0.375 0.875]
         * 0.25: [0 0 0 1 0 0 0 1]
         * 0.50: [0 1 0 1 0 1 0 1]
         * 0.75: [0 1 1 1 0 1 1 1]
         */
        // This definitely has a closed-form solution but let's just hard-code for now.
        let dither_add = Box::<[f32; 8]>::new([0.0/8.0, 4.0/8.0, 2.0/8.0, 6.0/8.0, 1.0/8.0, 5.0/8.0, 3.0/8.0, 7.0/8.0]);

        Dither { dither_add, gamma, rc, gc, bc, scale_idx, i_idx, x_idx, y_idx, o_idx }
    }
}

impl RenderBlock for Dither {
    fn execute(&mut self, state: &mut RenderState) {
        //let mut rng = rand::thread_rng();
        let rcolor = state.get_rcolor(self.i_idx);

        // Phase is (x + y) % 8
        let dither_phase = (state.get_scalar(self.x_idx) + 5.0*state.get_scalar(self.y_idx) + 3.0*state.get_scalar(0)).round() as usize;
        let dither_phase = dither_phase.rem_euclid(self.dither_add.len());
        //let dither_phase: usize = rng.gen_range(0..8);
        // Look up dither offset from phase
        let dither_offset = self.dither_add[dither_phase];
        //let dither_offset = rng.gen_range(0.0..1.0);
        let scale = state.get_scalar(self.scale_idx);

        let c = Color {
            r: clamp((scale*self.rc*rcolor.r.pow(self.gamma) + dither_offset).floor(), 0.0, 255.0) as u8,
            g: clamp((scale*self.gc*rcolor.g.pow(self.gamma) + dither_offset).floor(), 0.0, 255.0) as u8,
            b: clamp((scale*self.bc*rcolor.b.pow(self.gamma) + dither_offset).floor(), 0.0, 255.0) as u8,
        };

        state.set_color(self.o_idx, c);
    }
}
