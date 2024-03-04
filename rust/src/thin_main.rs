#![allow(dead_code)]

use tokio::sync;

use thin::thin_main;
use server::server_run;

mod constants;
mod display;
mod msg;
mod server;
mod thin;
mod var_types;

fn main() {
    let rt = tokio::runtime::Builder::new_multi_thread()
        .enable_all()
        .worker_threads(4)
        .build()
        .unwrap();

    // Create the broadcast channel
    let (tx_cfg, rx_cfg) = sync::broadcast::channel(16);
    let server_tx_cfg = tx_cfg.clone();

    rt.spawn(server_run(server_tx_cfg));
    rt.block_on(thin_main(rx_cfg));
}
