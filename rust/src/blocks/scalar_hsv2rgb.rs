use crate::render_block::{RenderState, RenderBlock};
use crate::var_types::RealColor;
use json::JsonValue;

pub struct ScalarHsv2Rgb {
    // Inputs

    // All scalars [0.0, 1.0]
    h_idx: usize,
    s_idx: usize,
    v_idx: usize,

    // Outputs
    o_idx: usize,
}

impl ScalarHsv2Rgb {
    pub fn from_obj(dict: &json::object::Object) -> Self {
        let input_obj = match dict.get("inputs").expect("Missing input definition") {
            JsonValue::Object(x) => x,
            _ => panic!("Initialization for ScalarHsv2Rgb inputs is not an object"),
        };

        let h_idx = input_obj.get("h").expect("Missing h input").as_usize().expect("Could not parse h input");
        let s_idx = input_obj.get("s").expect("Missing s input").as_usize().expect("Could not parse s input");
        let v_idx = input_obj.get("v").expect("Missing v input").as_usize().expect("Could not parse v input");

        let output_obj = match dict.get("outputs").expect("Missing output definition") {
            JsonValue::Object(x) => x,
            _ => panic!("Initialization for ScalarHsv2Rgb outputs is not an object"),
        };

        let o_idx = output_obj.get("o").expect("Missing o output").as_usize().expect("Could not parse o output");

        ScalarHsv2Rgb { h_idx, s_idx, v_idx, o_idx }
    }
}

impl RenderBlock for ScalarHsv2Rgb {
    fn execute(&mut self, state: &mut RenderState) {
        let v = state.get_scalar(self.v_idx).clamp(0.0, 1.0);
        let c = v * state.get_scalar(self.s_idx).clamp(0.0, 1.0);

        // Typically H is 0 to 360 degrees. Here we use the range 0.0 to 1.0. To get
        // H / 60 deg, we just multiply H by 6.0. Call this hp (H') to clarify that
        // this is not the raw H value itself.
        let hp = state.get_scalar(self.h_idx) * 6.0;
        let x = c * (1.0 - (hp.rem_euclid(2.0) - 1.0).abs());

        let sector = hp.floor().rem_euclid(6.0) as u8;

        let rcolor = match sector {
            0 => RealColor {r: c, g: x, b: 0.0},
            1 => RealColor {r: x, g: c, b: 0.0},
            2 => RealColor {r: 0.0, g: c, b: x},
            3 => RealColor {r: 0.0, g: x, b: c},
            4 => RealColor {r: x, g: 0.0, b: c},
            5 => RealColor {r: c, g: 0.0, b: x},
            x => panic!("Invalid HSV sector {x}")
        };

        state.set_rcolor(self.o_idx, rcolor);
    }
}
