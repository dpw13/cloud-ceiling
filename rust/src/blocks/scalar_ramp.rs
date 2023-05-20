use crate::render_block::{RenderState, RenderBlock};
use json::JsonValue;

pub struct ScalarRamp {
    // Inputs
    f_idx: usize,
    min_idx: usize,
    max_idx: usize,

    i_idx: usize,

    // Outputs
    o_idx: usize,
}

impl ScalarRamp {
    pub fn from_obj(dict: &json::object::Object) -> Self {
        let input_obj = match dict.get("inputs").expect("Missing input definition") {
            JsonValue::Object(x) => x,
            _ => panic!("Initialization for ScalarRamp inputs is not an object"),
        };

        let f_idx = input_obj.get("f").expect("Missing frequency input").as_usize().expect("Could not parse frequency input");
        let min_idx = input_obj.get("min").expect("Missing min input").as_usize().expect("Could not parse min input");
        let max_idx = input_obj.get("max").expect("Missing max input").as_usize().expect("Could not parse max input");
        let i_idx = input_obj.get("i").expect("Missing i input").as_usize().expect("Could not parse i input");

        let output_obj = match dict.get("outputs").expect("Missing output definition") {
            JsonValue::Object(x) => x,
            _ => panic!("Initialization for ScalarRamp outputs is not an object"),
        };

        let o_idx = output_obj.get("o").expect("Missing o output").as_usize().expect("Could not parse o output");

        ScalarRamp { f_idx, min_idx, max_idx, i_idx, o_idx }
    }
}

impl RenderBlock for ScalarRamp {
    fn execute(&mut self, state: &mut RenderState) {
        // ramp function of frequency f
        let phase = state.get_scalar(self.i_idx) * state.get_scalar(self.f_idx);

        let min = state.get_scalar(self.min_idx);
        let mag = state.get_scalar(self.max_idx) - min;

        let out = phase.rem_euclid(1.0) * mag + min;

        state.set_scalar(self.o_idx, out);
    }
}
