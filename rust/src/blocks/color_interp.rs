use crate::render_block::{RenderState, RenderBlock};
use json::JsonValue;

pub struct ColorInterp {
    // Inputs
    color_idxs: Vec<usize>,
    point_idxs: Vec<usize>,

    val_idx: usize,

    // Outputs
    o_idx: usize,
}

impl ColorInterp {
    pub fn from_obj(dict: &json::object::Object) -> Self {
        let input_obj = match dict.get("inputs").expect("Missing input definition") {
            JsonValue::Object(x) => x,
            _ => panic!("Initialization for ColorInterp inputs is not a list"),
        };

        let color_array = match input_obj.get("color").expect("Missing color inputs") {
            JsonValue::Array(x) => x,
            _ => panic!("Color input must be array"),
        };

        let mut color_idxs = Vec::<usize>::with_capacity(color_array.len());
        for c in color_array {
            color_idxs.push(c.as_usize().expect("Could not parse color index"));
        }

        let point_array = match input_obj.get("point").expect("Missing color inputs") {
            JsonValue::Array(x) => x,
            _ => panic!("Color input must be array"),
        };

        let mut point_idxs = Vec::<usize>::with_capacity(point_array.len());
        for p in point_array {
            point_idxs.push(p.as_usize().expect("Could not parse point index"));
        }

        let val_idx = input_obj.get("val").expect("Missing value input").as_usize().expect("Could not parse value input");

        let outputs = dict.get("outputs").expect("Missing input definition");
        let output_obj = match outputs {
            JsonValue::Object(x) => x,
            _ => panic!("Initialization for ColorInterp outputs is not a list"),
        };

        let o_idx = output_obj.get("o").expect("Missing o output").as_usize().expect("Could not parse o output");

        return ColorInterp { color_idxs, point_idxs, val_idx, o_idx };
    }
}

impl RenderBlock for ColorInterp {
    fn execute(&mut self, state: &mut RenderState) {
        // Get our current value
        let val = state.get_scalar(self.val_idx);
        // Find which pair of points this value falls between
        let i = self.point_idxs.iter().position(|x| val <= state.get_scalar(*x)).expect("{val} is outside of map limits") - 1;
        //print!("Using index {i}, original value is {val}\n");

        // Scale the independent variable
        let start_val = state.get_scalar(i);
        let end_val = state.get_scalar(i+1);
        let alpha = (val - start_val)/(end_val - start_val);
        //print!("alpha = {alpha}\n");

        // Perform the interpolation
        let start_color = state.get_color(i);
        let end_color = state.get_color(i+1);
        let color = (*start_color * (1.0 - alpha)) + (*end_color * alpha);

        state.set_color(self.o_idx, color);
    }
}
