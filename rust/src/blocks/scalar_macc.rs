use crate::render_block::{RenderBlock, RenderState};
use json::JsonValue;

pub struct ScalarMacc {
    // Inputs
    m_idxs: Vec<usize>,
    x_idxs: Vec<usize>,

    // Outputs
    o_idx: usize,
}

impl ScalarMacc {
    pub fn from_obj(dict: &json::object::Object) -> Self {
        let input_obj = match dict.get("inputs").expect("Missing input definition") {
            JsonValue::Object(x) => x,
            _ => panic!("Initialization for ScalarMacc inputs is not an object"),
        };

        let m_array = match input_obj.get("m").expect("Missing m inputs") {
            JsonValue::Array(x) => x,
            _ => panic!("M input must be array"),
        };

        let x_array = match input_obj.get("x").expect("Missing x inputs") {
            JsonValue::Array(x) => x,
            _ => panic!("X input must be array"),
        };

        if m_array.len() != x_array.len() {
            panic!("M and X inputs must be the same length")
        }

        let mut m_idxs = Vec::<usize>::with_capacity(m_array.len());
        for m in m_array {
            m_idxs.push(m.as_usize().expect("Could not parse m index"));
        }

        let mut x_idxs = Vec::<usize>::with_capacity(m_array.len());
        for x in x_array {
            x_idxs.push(x.as_usize().expect("Could not parse x index"));
        }

        let output_obj = match dict.get("outputs").expect("Missing output definition") {
            JsonValue::Object(x) => x,
            _ => panic!("Initialization for ScalarMacc outputs is not an object"),
        };

        let o_idx = output_obj
            .get("o")
            .expect("Missing o output")
            .as_usize()
            .expect("Could not parse o output");

        ScalarMacc {
            m_idxs,
            x_idxs,
            o_idx,
        }
    }
}

impl RenderBlock for ScalarMacc {
    fn execute(&mut self, state: &mut RenderState) {
        let mut out: f32 = 0.0;
        for (m_idx, x_idx) in self.m_idxs.iter().zip(&self.x_idxs) {
            out += state.get_scalar(*m_idx) * state.get_scalar(*x_idx);
        }
        state.set_scalar(self.o_idx, out);
    }
}
