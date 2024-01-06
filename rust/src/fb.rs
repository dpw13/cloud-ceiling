use std::thread::sleep;
use std::time::{Duration, Instant};
use std::vec::Vec;

use magick_rust::magick_wand_genesis;

use tokio::sync;

use json::JsonValue;

use crate::args::Args;
use crate::blocks::block_factory;
use crate::constants;
use crate::display::LedDisplay;
use crate::msg::Message;
use crate::render_block::{RenderBlock, RenderState};

fn update_cfg(
    json_obj: json::object::Object,
    state: &mut RenderState,
    blocks: &mut Vec<Box<dyn RenderBlock>>,
) {
    state.from_obj(json_obj.get("vars").expect("No vars stanza in JSON"));

    let block_list = match json_obj
        .get("primitives")
        .expect("No primitives stanza in JSON")
    {
        JsonValue::Array(x) => x,
        _ => panic!("Primitives stanza is not an array"),
    };

    blocks.clear();
    for b in block_list {
        blocks.push(block_factory(b));
    }

    print!("Config updated\n");
}

pub fn fb_main(args: &Args, mut rx_cfg: sync::broadcast::Receiver<Message>) {
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
        while let Ok(msg) = rx_cfg.try_recv() {
            match msg {
                Message::Config(json_obj) => update_cfg(json_obj, &mut state, &mut blocks),
                Message::SetScalar(v) => state.set_scalar(v.index, v.value),
                Message::SetPosition(v) => state.set_position(v.index, v.value),
                Message::SetColor(v) => state.set_color(v.index, v.value),
                Message::SetRColor(v) => state.set_rcolor(v.index, v.value),
            }
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

        if args.debug {
            state.debug();
            //break;
        }

        frame += 1;
    }

    println!(
        "{} frames in {:?}. Spent {:?} in flush.",
        args.frame_cnt,
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
