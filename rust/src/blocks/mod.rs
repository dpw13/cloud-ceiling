pub mod scalar_add;

use json::JsonValue;
use crate::render_block::RenderBlock;
use scalar_add::ScalarAdd;

pub fn block_factory(v: &JsonValue) -> Box<dyn RenderBlock> {
    let dict = match v {
        JsonValue::Object(ref x) => x,
        _ => panic!("Position is not an object"),
    };

    let name = dict.get("name").expect("Render block missing name").as_str().expect("Render block name is not a string");

    match name {
        "scalar_add" => Box::new(ScalarAdd::from_obj(dict)),
        _ => panic!("Unknown RenderBlock {}", name)
    }
}
