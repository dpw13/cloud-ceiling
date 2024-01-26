#![allow(dead_code)]

use std::fs::File;
use std::io::prelude::*;

use tokio::sync;

use clap::Parser;
use json::JsonValue;

use args::Args;
use fb::fb_main;
use msg::Message;
use server::server_run;

mod animations;
mod args;
mod blocks;
mod constants;
mod display;
mod fb;
mod msg;
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
    let (tx_cfg, rx_cfg) = sync::broadcast::channel(16);
    let server_tx_cfg = tx_cfg.clone();

    let cfg = init_config(&args);

    if let Err(e) = tx_cfg.send(Message::Config(cfg)) {
        print!("Error sending new config: {e}\n");
    }

    rt.spawn(async move { server_run(server_tx_cfg) });
    rt.block_on(async move { fb_main(&args, rx_cfg) });
}
