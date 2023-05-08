use std::time::{Duration, Instant};
use std::thread::sleep;
use std::fs::File;
use std::io::prelude::*;
use std::vec::Vec;

use magick_rust::{magick_wand_genesis};

use clap::{Parser};

use json::{self, JsonValue};

use display::LedDisplay;

mod constants;
mod display;
mod animations;

#[derive(Parser)]
#[command(author, version, about, long_about = None)]
struct Args {
    #[arg(short, long, default_value_t = 0)]
    frame_cnt: u32,

    #[arg(short, long, default_value_t = String::from("config.json"))]
    json: String,
}

pub struct RenderState {
    scalars: Vec<f32>,
    positions: Vec<Position>,
    colors: Vec<Color>,
}

pub trait RenderBlock {
    fn execute(&mut self, state: &mut RenderState);
}

struct ScalarAdd {
    // Inputs
    a_idx: usize,
    b_idx: usize,

    // Outputs
    o_idx: i32
}

impl ScalarAdd {
    fn from_obj(dict: &json::object::Object) -> Self {
        let inputs = dict.get("inputs").expect("Missing input definition");
        let input_obj = match inputs {
            json::JsonValue::Object(x) => x,
            _ => panic!("Initialization for flots is not a list"),
        };

        let a_idx = input_obj.get("a").expect("Missing a input").as_usize().expect("Could not parse a input");
        let b_idx = input_obj.get("b").expect("Missing b input").as_usize().expect("Could not parse b input");

        let outputs = dict.get("inputs").expect("Missing input definition");
        let output_obj = match outputs {
            json::JsonValue::Object(x) => x,
            _ => panic!("Initialization for flots is not a list"),
        };

        let o_idx = output_obj.get("o").expect("Missing o output").as_i32().expect("Could not parse o output");

        return ScalarAdd { a_idx, b_idx, o_idx };
    }
}

impl RenderBlock for ScalarAdd {
    fn execute(&mut self, state: &mut RenderState) {
        state.scalars[self.o_idx as usize] = state.scalars[self.a_idx] + state.scalars[self.b_idx];
    }
}

fn block_factory(v: &json::JsonValue) -> Box<dyn RenderBlock> {
    let dict = match v {
        json::JsonValue::Object(ref x) => x,
        _ => panic!("Position is not an object"),
    };

    let name = dict.get("name").expect("Render block missing name").as_str().expect("Render block name is not a string");

    match name {
        "scalar_add" => Box::new(ScalarAdd::from_obj(dict)),
        _ => panic!("Unknown RenderBlock {}", name)
    }
}

#[derive(Default, Clone)]
struct Position {
    x: f32,
    y: f32,
}

impl Position {
    pub fn from_obj(&mut self, v: &json::JsonValue) {
        let dict = match v {
            json::JsonValue::Object(ref x) => x,
            _ => panic!("Position is not an object"),
        };

        self.x = dict.get("x").expect("No x parameter in Position").as_f32().expect("Failed to interpret x parameter");
        self.y = dict.get("y").expect("No y parameter in Position").as_f32().expect("Failed to interpret y parameter");
    }
}

#[derive(Default, Clone)]
struct Color {
    r: u8,
    g: u8,
    b: u8,
}

impl Color {
    pub fn from_obj(&mut self, v: &json::JsonValue) {
        let dict = match v {
            json::JsonValue::Object(ref x) => x,
            _ => panic!("Position is not an object"),
        };

        self.r = dict.get("r").expect("No r parameter in Color").as_u8().expect("Failed to interpret r parameter");
        self.g = dict.get("g").expect("No g parameter in Color").as_u8().expect("Failed to interpret g parameter");
        self.b = dict.get("b").expect("No b parameter in Color").as_u8().expect("Failed to interpret b parameter");
    }
}

impl RenderState {
    pub fn new() -> Self {
        let scalars = Vec::<f32>::with_capacity(0);
        let positions = Vec::<Position>::with_capacity(0);
        let colors = Vec::<Color>::with_capacity(0);

        RenderState {scalars, positions, colors}
    }

    pub fn from_obj(&mut self, v: &json::JsonValue) {
        let dict = match v {
            json::JsonValue::Object(x) => x,
            _ => panic!("Position is not an object"),
        };

        let val = dict.get("float").expect("Missing 'float' initialization");
        let list = match val {
            json::JsonValue::Array(x) => x,
            _ => panic!("Initialization for flots is not a list"),
        };
        self.scalars.resize(list.len(), 0.0);
        for (i, o) in list.iter().enumerate() {
            self.scalars[i] = o.as_f32().expect("Failed to interpret scalar value");
        }

        let val = dict.get("positions").expect("Missing 'positions' initialization");
        let list = match val {
            json::JsonValue::Array(x) => x,
            _ => panic!("Initialization for flots is not a list"),
        };
        self.positions.resize(list.len(), Default::default());
        for (i, o) in list.iter().enumerate() {
            self.positions[i].from_obj(o);
        }

        let val = dict.get("colors").expect("Missing 'colors' initialization");
        let list = match val {
            json::JsonValue::Array(x) => x,
            _ => panic!("Initialization for flots is not a list"),
        };
        self.colors.resize(list.len(), Default::default());
        for (i, o) in list.iter().enumerate() {
            self.colors[i].from_obj(o);
        }
    }
}

fn main() {
    let args = Args::parse();

    // Initialize magick-wand
    magick_wand_genesis();

    let disp = LedDisplay::new();
    let id = disp.read_id();

    println!("FPGA ID: 0x{:x}", id);
    println!("Starting empty count: {}", disp.empty_count());

    let mut fb = disp.borrow_fb();
    fb.fill(0);

    // Config

    // Open the path in read-only mode, returns `io::Result<File>`
    let mut file = match File::open(&args.json) {
        Err(why) => panic!("couldn't open {}: {}", args.json, why),
        Ok(file) => file,
    };

    // Read the file contents into a string, returns `io::Result<usize>`
    let mut s = String::new();
    let json_val = match file.read_to_string(&mut s) {
        Err(why) => panic!("couldn't read {}: {}", args.json, why),
        Ok(_) => json::parse(&s).unwrap(),
    };

    let json_obj = match json_val {
        json::JsonValue::Object(x) => x,
        _ => panic!("JSON configuration is not an object"),
    };

    let mut state = RenderState::new();

    state.from_obj(json_obj.get("vars").expect("No vars stanza in JSON"));

    let block_list = match json_obj.get("primitives").expect("No primitives stanza in JSON") {
        json::JsonValue::Array(x) => x,
        _ => panic!("Primitives stanza is not an array"),
    };

    let mut blocks = Vec::<Box<dyn RenderBlock>>::with_capacity(block_list.len());

    for b in block_list {
        blocks.push(block_factory(b));
    }

    let now = Instant::now();

    let mut frame: u32 = 0;
    while args.frame_cnt == 0 || frame < args.frame_cnt {
        state.scalars[0] = frame as f32;
        for x in 0..constants::STRING_COUNT {
            state.scalars[1] = x as f32;
            for y in 0..constants::LED_COUNT {
                state.scalars[2] = y as f32;

                for block in blocks.iter_mut() {
                    block.as_mut().execute(&mut state);
                }

                let idx = constants::fb_idx(x, y);

                fb[idx + 0] = state.colors[0].b;
                fb[idx + 1] = state.colors[0].r;
                fb[idx + 2] = state.colors[0].g;
            }
        }
        // Render:
        //anim.render(frame, &mut fb);
        // Call ioctl to DMA to hardware
        disp.flush();
        frame += 1;
    }

    println!("{} frames in {:?}. Spent {:?} in flush.", args.frame_cnt, now.elapsed(), disp.wait_time.get());

    // Wait for last frame to flush
    sleep(Duration::from_millis(5));
    disp.read_id();

    // Blank
    fb.fill(0);
    disp.flush();
    // Wait for DMA to finish. Otherwise the last blank frame doesn't get flushed.
    sleep(Duration::from_millis(5));

    while disp.empty_count() < 8000 {
        sleep(Duration::from_micros(100));
    }
    println!("Ending empty count: {}", disp.empty_count());
}
