use std::thread::sleep;
use std::time::{Duration, Instant};

use tokio::sync;

use crate::constants;
use crate::display::LedDisplay;
use crate::modular_msg::ModularMessage;

pub async fn movie_main(mut rx_cfg: sync::broadcast::Receiver<ModularMessage>) {
    /* Framebuffer initialization */

    let disp = LedDisplay::new();
    let id = disp.read_id();

    println!("FPGA ID: 0x{:x}", id);
    println!("Starting empty count: {}", disp.empty_count());

    let mut fb = disp.borrow_fb();
    fb.fill(0);

    let now = Instant::now();
    let mut frame: u32 = 0;

    // Blocking wait to receive new message
    while let Ok(msg) = rx_cfg.recv().await {
        match msg {
            ModularMessage::SetData(buf) => {
                // Swizzle image
                for x in 0..constants::LED_COUNT {
                    for y in 0..constants::STRING_COUNT {
                        let dst_idx = constants::fb_idx(x, y);
                        let src_idx = constants::px_idx_tpose(x, y);

                        // RGB to BRG
                        fb[dst_idx + 0] = buf.value[src_idx + 2];
                        fb[dst_idx + 1] = buf.value[src_idx + 0];
                        fb[dst_idx + 2] = buf.value[src_idx + 1];
                    }
                }

                disp.flush();
                frame += 1;
            },
            _ => print!("Unimplemented: {:?}\n", msg),
        }
    }

    println!(
        "{} frames in {:?}. Spent {:?} in flush.",
        frame,
        now.elapsed(),
        disp.wait_time.get()
    );

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
