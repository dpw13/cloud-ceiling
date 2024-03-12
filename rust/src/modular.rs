#![allow(dead_code)]

use std::fs::File;
use std::io::prelude::*;

use tokio::sync;

use clap::Parser;
use json::JsonValue;

use args::Args;
use led_ctrl::led_main;
use mod_ctrl::fb_main;
use modular_msg::ModularMessage;
use server::server_run;

mod args;
mod blocks;
mod constants;
mod display;
mod led_ctrl;
mod led_msg;
mod mod_ctrl;
mod modular_msg;
mod render_block;
mod server;
mod var_types;

fn init_config(args: &Args) -> json::object::Object {
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

    match json_val {
        JsonValue::Object(x) => x,
        _ => panic!("JSON configuration is not an object"),
    }
}

fn main() {
    let args = Args::parse();

    let rt = tokio::runtime::Builder::new_multi_thread()
        .enable_all()
        .worker_threads(4)
        .build()
        .unwrap();

    // Create the broadcast channel
    let (led_cmd, led_rx) = sync::broadcast::channel(16);
    let (mod_cmd, mod_rx) = sync::broadcast::channel(16);
    let server_mod_cmd = mod_cmd.clone();

    let cfg = init_config(&args);

    if let Err(e) = mod_cmd.send(ModularMessage::Config(cfg)) {
        print!("Error sending new config: {e}\n");
    }

    rt.spawn(server_run(server_mod_cmd, led_cmd));
    rt.spawn(led_main(led_rx));
    rt.block_on(async move { fb_main(&args, mod_rx) });
}
