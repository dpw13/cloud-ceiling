pub mod scalar_add;
pub mod color_interp;
pub mod dither;

use json::JsonValue;

use crate::render_block::RenderBlock;
use scalar_add::ScalarAdd;
use color_interp::ColorInterp;
use dither::Dither;

pub fn block_factory(v: &JsonValue) -> Box<dyn RenderBlock> {
    let dict = match v {
        JsonValue::Object(ref x) => x,
        _ => panic!("Position is not an object"),
    };

    let name = dict.get("type").expect("Render block missing name").as_str().expect("Render block name is not a string");

    match name {
        "scalar_add" => Box::new(ScalarAdd::from_obj(dict)),
        "color_interp" => Box::new(ColorInterp::from_obj(dict)),
        "dither" => Box::new(Dither::from_obj(dict)),
        _ => panic!("Unknown RenderBlock {}", name)
    }
}
