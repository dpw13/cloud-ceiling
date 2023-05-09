use crate::render_block::{RenderState, RenderBlock};

pub struct ScalarAdd {
    // Inputs
    a_idx: usize,
    b_idx: usize,

    // Outputs
    o_idx: i32,
}

impl ScalarAdd {
    pub fn from_obj(dict: &json::object::Object) -> Self {
        let inputs = dict.get("inputs").expect("Missing input definition");
        let input_obj = match inputs {
            json::JsonValue::Object(x) => x,
            _ => panic!("Initialization for ScalarAdd inputs is not a list"),
        };

        let a_idx = input_obj.get("a").expect("Missing a input").as_usize().expect("Could not parse a input");
        let b_idx = input_obj.get("b").expect("Missing b input").as_usize().expect("Could not parse b input");

        let outputs = dict.get("outputs").expect("Missing input definition");
        let output_obj = match outputs {
            json::JsonValue::Object(x) => x,
            _ => panic!("Initialization for ScalarAdd outputs is not a list"),
        };

        let o_idx = output_obj.get("o").expect("Missing o output").as_i32().expect("Could not parse o output");

        return ScalarAdd { a_idx, b_idx, o_idx };
    }
}

impl RenderBlock for ScalarAdd {
    fn execute(&mut self, state: &mut RenderState) {
        state.set_scalar(self.o_idx as usize, state.get_scalar(self.a_idx) + state.get_scalar(self.b_idx));
    }
}
