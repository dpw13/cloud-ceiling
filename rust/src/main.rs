#![allow(dead_code)]

use std::time::{Duration, Instant};
use std::thread::sleep;
use std::fs::File;
use std::io::prelude::*;
use std::vec::Vec;
use std::convert::Infallible;
use std::net::SocketAddr;

use magick_rust::{magick_wand_genesis};

use hyper::{Body, Request, Response, Server};
use hyper::service::{make_service_fn, service_fn};
use tokio::sync;

use clap::{Parser};
use json::JsonValue;

use display::LedDisplay;
use render_block::{RenderBlock, RenderState};
use blocks::block_factory;

mod render_block;
mod constants;
mod display;
mod animations;
mod blocks;

#[derive(Parser)]
#[command(author, version, about, long_about = None)]
struct Args {
    #[arg(short, long, default_value_t = 0)]
    frame_cnt: u32,

    #[arg(short, long, default_value_t = String::from("config.json"))]
    json: String,
}

async fn endpoint_impl(_req: Request<Body>, _tx_cfg: sync::broadcast::Sender<json::object::Object>) -> Result<Response<Body>, Infallible> {
    Ok(Response::new("Hello, World".into()))
}

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

async fn server_setup(tx_cfg: sync::broadcast::Sender<json::object::Object>) {
    /* HTTP Server initialization */

    // We'll bind to 127.0.0.1:3000
    let addr = SocketAddr::from(([127, 0, 0, 1], 3000));

    // A `Service` is needed for every connection, so this
    // creates one from our `endpoint_impl` function.
    let make_svc = make_service_fn(move |conn| {
        // Clone the broadcast sender before we create the service function itself.
        let tx_cfg = tx_cfg.clone();
        print!("Got connection from {conn:?}\n");

        // This is the actual service function, which will reference a cloned tx_cfg.
        async move {
            // service_fn converts our function into a `Service`
            Ok::<_, Infallible>(service_fn(move |req| { endpoint_impl(req, tx_cfg.clone()) }))
        }
    });

    let server = Server::bind(&addr).serve(make_svc);

    print!("Server listening on {addr}\n");

    if let Err(e) = server.await {
        panic!("Server error: {}", e);
    }

    print!("Server terminated, should never get here");

}

fn main() {
    let args = Args::parse();

    let rt = tokio::runtime::Builder::new_multi_thread()
        .enable_all()
        .worker_threads(4)
        .build()
        .unwrap();

    // Create the broadcast channel
    let (tx_cfg, rx_cfg) = sync::broadcast::channel(1);
    let server_tx_cfg = tx_cfg.clone();

    let cfg = init_config(&args);

    if let Err(e) = tx_cfg.send(cfg) {
        print!("Error sending new config: {e}\n");
    }

    rt.spawn(async move { server_setup(server_tx_cfg).await });
    rt.block_on(async move { fb_main(&args, rx_cfg) });

}

fn update_cfg(json_obj: json::object::Object, state: &mut RenderState, blocks: &mut Vec<Box<dyn RenderBlock>>) {
    state.from_obj(json_obj.get("vars").expect("No vars stanza in JSON"));

    let block_list = match json_obj.get("primitives").expect("No primitives stanza in JSON") {
        JsonValue::Array(x) => x,
        _ => panic!("Primitives stanza is not an array"),
    };

    blocks.clear();
    for b in block_list {
        blocks.push(block_factory(b));
    }
}

fn fb_main(args: &Args, mut rx_cfg: sync::broadcast::Receiver<json::object::Object>) {
    /* Framebuffer initialization */
    // Initialize magick-wand
    magick_wand_genesis();

    let disp = LedDisplay::new();
    let id = disp.read_id();

    println!("FPGA ID: 0x{:x}", id);
    println!("Starting empty count: {}", disp.empty_count());

    let mut fb = disp.borrow_fb();
    fb.fill(0);

    let mut state = RenderState::new();
    let mut blocks = Vec::<Box<dyn RenderBlock>>::new();

    let now = Instant::now();

    let mut frame: u32 = 0;
    while args.frame_cnt == 0 || frame < args.frame_cnt {
        // Update config if there's anything new
        if let Ok(json_obj) = rx_cfg.try_recv() {
            print!("Updated config");
            update_cfg(json_obj, &mut state, &mut blocks);
        }

        state.set_scalar(0, frame as f32);
        for x in 0..constants::LED_COUNT {
            state.set_scalar(1, x as f32);
            for y in 0..constants::STRING_COUNT {
                state.set_scalar(2, y as f32);

                for block in blocks.iter_mut() {
                    block.as_mut().execute(&mut state);
                }

                let idx = constants::fb_idx(x, y);

                let c = state.get_color(0);
                fb[idx + 0] = c.b;
                fb[idx + 1] = c.r;
                fb[idx + 2] = c.g;
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
