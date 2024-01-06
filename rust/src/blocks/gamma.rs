use json::JsonValue;
use num_traits::{clamp, Pow};
//use rand::Rng;

use crate::render_block::{RenderBlock, RenderState};
use crate::var_types::Color;

pub struct Gamma {
    // Params
    gamma: f32,
    // color coefficients
    rc: f32,
    gc: f32,
    bc: f32,

    // Inputs
    i_idx: usize,

    x_idx: usize,
    y_idx: usize,

    // Outputs
    o_idx: usize,
}

impl Gamma {
    pub fn from_obj(dict: &json::object::Object) -> Self {
        let input_obj = match dict.get("params").expect("Missing params definition") {
            JsonValue::Object(x) => x,
            _ => panic!("Initialization for Gamma params is not an object"),
        };
        let gamma = input_obj
            .get("gamma")
            .expect("Missing gamma input")
            .as_f32()
            .expect("Could not parse gamma input");
        let rc = input_obj
            .get("rc")
            .expect("Missing R coefficient input")
            .as_f32()
            .expect("Could not parse R coefficient input");
        let gc = input_obj
            .get("gc")
            .expect("Missing G coefficient input")
            .as_f32()
            .expect("Could not parse G coefficient input");
        let bc = input_obj
            .get("bc")
            .expect("Missing B coefficient input")
            .as_f32()
            .expect("Could not parse B coefficient input");

        let input_obj = match dict.get("inputs").expect("Missing input definition") {
            JsonValue::Object(x) => x,
            _ => panic!("Initialization for Gamma inputs is not an object"),
        };

        let i_idx = input_obj
            .get("i")
            .expect("Missing i input")
            .as_usize()
            .expect("Could not parse i input");
        let x_idx = input_obj
            .get("x")
            .expect("Missing x input")
            .as_usize()
            .expect("Could not parse x input");
        let y_idx = input_obj
            .get("y")
            .expect("Missing y input")
            .as_usize()
            .expect("Could not parse y input");

        let output_obj = match dict.get("outputs").expect("Missing output definition") {
            JsonValue::Object(x) => x,
            _ => panic!("Initialization for Gamma outputs is not an object"),
        };

        let o_idx = output_obj
            .get("o")
            .expect("Missing o output")
            .as_usize()
            .expect("Could not parse o output");

        Gamma {
            gamma,
            rc,
            gc,
            bc,
            i_idx,
            x_idx,
            y_idx,
            o_idx,
        }
    }
}

impl RenderBlock for Gamma {
    fn execute(&mut self, state: &mut RenderState) {
        let rcolor = state.get_rcolor(self.i_idx);

        let c = Color {
            r: clamp(
                (255.0 * self.rc * rcolor.r.pow(self.gamma)).floor(),
                0.0,
                255.0,
            ) as u8,
            g: clamp(
                (255.0 * self.gc * rcolor.g.pow(self.gamma)).floor(),
                0.0,
                255.0,
            ) as u8,
            b: clamp(
                (255.0 * self.bc * rcolor.b.pow(self.gamma)).floor(),
                0.0,
                255.0,
            ) as u8,
        };

        state.set_color(self.o_idx, c);
    }
}
