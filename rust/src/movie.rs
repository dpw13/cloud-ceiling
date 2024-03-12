#![allow(dead_code)]

use tokio::sync;

use movie_ctrl::movie_main;
use server::server_run;

mod constants;
mod display;
mod led_msg;
mod modular_msg;
mod server;
mod movie_ctrl;
mod var_types;

fn main() {
    let rt = tokio::runtime::Builder::new_multi_thread()
        .enable_all()
        .worker_threads(4)
        .build()
        .unwrap();

    // Create the broadcast channel
    let (mod_cmd, mod_rx) = sync::broadcast::channel(16);
    let (led_cmd, led_rx) = sync::broadcast::channel(16);

    rt.spawn(server_run(mod_cmd, led_cmd));
    rt.block_on(movie_main(mod_rx));
}
