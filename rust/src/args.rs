use clap::{Parser};

#[derive(Parser)]
#[command(author, version, about, long_about = None)]
pub struct Args {
    #[arg(short, long, default_value_t = 0)]
    pub frame_cnt: u32,

    #[arg(short, long, default_value_t = String::from("config.json"))]
    pub json: String,
}
