pub mod color_interp;
pub mod dither;
pub mod gamma;
pub mod scalar_add;
pub mod scalar_hsv2rgb;
pub mod scalar_macc;
pub mod scalar_ramp;
pub mod scalar_triangle;

use json::JsonValue;

use crate::render_block::RenderBlock;
use color_interp::ColorInterp;
use dither::Dither;
use gamma::Gamma;
use scalar_add::ScalarAdd;
use scalar_hsv2rgb::ScalarHsv2Rgb;
use scalar_macc::ScalarMacc;
use scalar_ramp::ScalarRamp;
use scalar_triangle::ScalarTriangle;

pub fn block_factory(v: &JsonValue) -> Box<dyn RenderBlock> {
    let dict = match v {
        JsonValue::Object(ref x) => x,
        _ => panic!("Position is not an object"),
    };

    let name = dict
        .get("type")
        .expect("Render block missing name")
        .as_str()
        .expect("Render block name is not a string");

    match name {
        "color_interp" => Box::new(ColorInterp::from_obj(dict)),
        "dither" => Box::new(Dither::from_obj(dict)),
        "gamma" => Box::new(Gamma::from_obj(dict)),
        "scalar_add" => Box::new(ScalarAdd::from_obj(dict)),
        "scalar_hsv2rgb" => Box::new(ScalarHsv2Rgb::from_obj(dict)),
        "scalar_macc" => Box::new(ScalarMacc::from_obj(dict)),
        "scalar_ramp" => Box::new(ScalarRamp::from_obj(dict)),
        "scalar_triangle" => Box::new(ScalarTriangle::from_obj(dict)),
        _ => panic!("Unknown RenderBlock {}", name),
    }
}
