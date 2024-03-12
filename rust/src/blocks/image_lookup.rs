use crate::render_block::{RenderBlock, RenderState};
use crate::var_types::Color;

use json::JsonValue;
use num_traits::ToPrimitive;
use num_enum::FromPrimitive;

pub struct ImageLookup {
    // Inputs
    width_idx: usize,
    height_idx: usize,

    x_idx: usize,
    y_idx: usize,

    mode_idx: usize,
    data_idx: usize,

    // Outputs
    o_idx: usize, // color
}

#[derive(Debug, Clone, PartialEq, FromPrimitive)]
#[repr(u8)]
enum LookupMode {
    #[num_enum(default)]
    Single,
    Tile,
}

impl ImageLookup {
    pub fn from_obj(dict: &json::object::Object) -> Self {
        let input_obj = match dict.get("inputs").expect("Missing input definition") {
            JsonValue::Object(x) => x,
            _ => panic!("Initialization for ImageLookup inputs is not an object"),
        };

        let width_idx = input_obj
            .get("width")
            .expect("Missing width input")
            .as_usize()
            .expect("Could not parse width input");
        let height_idx = input_obj
            .get("height")
            .expect("Missing height input")
            .as_usize()
            .expect("Could not parse height input");

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

        let mode_idx = input_obj
            .get("mode")
            .expect("Missing mode input")
            .as_usize()
            .expect("Could not parse mode input");
        let data_idx = input_obj
            .get("data")
            .expect("Missing data input")
            .as_usize()
            .expect("Could not parse data input");

        let output_obj = match dict.get("outputs").expect("Missing output definition") {
            JsonValue::Object(x) => x,
            _ => panic!("Initialization for ImageLookup outputs is not an object"),
        };

        let o_idx = output_obj
            .get("o")
            .expect("Missing o output")
            .as_usize()
            .expect("Could not parse o output");

        ImageLookup {
            width_idx,
            height_idx,
            x_idx,
            y_idx,
            mode_idx,
            data_idx,
            o_idx,
        }
    }
}

impl RenderBlock for ImageLookup {
    fn execute(&mut self, state: &mut RenderState) {
        let width = state.get_scalar(self.width_idx).round().clamp(1.0, 1024.0);
        let height = state.get_scalar(self.height_idx).round().clamp(1.0, 1024.0);

        let x = state.get_scalar(self.x_idx) * 1.0;
        let y = state.get_scalar(self.y_idx) * 2.2;

        let data = state.get_data(self.data_idx);

        let mut i = -1;
        let mut j = -1;

        match LookupMode::from(state.get_scalar(self.mode_idx).to_u8().unwrap()) {
            LookupMode::Single => {
                if x >= 0.0 && x < width {
                    i = x.round().to_isize().unwrap();
                }
                if y >= 0.0 && y < height {
                    j = y.round().to_isize().unwrap();
                }
            }
            LookupMode::Tile => {
                i = x.rem_euclid(width).round().to_isize().unwrap();
                j = y.rem_euclid(height).round().to_isize().unwrap();
            }
        }

        let mut r = 0u8;
        let mut g = 0u8;
        let mut b = 0u8;

        if i >= 0 && j >= 0 {
            let idx = 3*(i + j*(width as isize)) as usize;
            if idx + 2 < data.len() {
                r = data[idx + 0];
                g = data[idx + 1];
                b = data[idx + 2];
            }
        }

        state.set_color(self.o_idx, Color {r, g, b});
    }
}
