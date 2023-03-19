use std::time::{Duration, Instant};
use std::thread::sleep;

use magick_rust::{magick_wand_genesis};

use clap::{Parser};

use animations::strobe::Strobe;
use animations::waves::{Waves, WaveArgs};
use animations::common::Renderable;
use display::LedDisplay;

mod constants;
mod display;
mod animations;

#[derive(Parser)]
#[command(author, version, about, long_about = None)]
struct Args {
    #[arg(short, long, default_value_t = 0)]
    frame_cnt: u32,

    #[command(subcommand)]
    command: Commands,
}

#[derive(clap::Subcommand)]
enum Commands {
    Strobe,
    Waves(WaveArgs),
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
    let mut anim: Box<dyn Renderable>;

    match args.command {
        Commands::Strobe => {
            anim = Box::new(Strobe::new());
        }
        Commands::Waves(wave_args) => {
            anim = Box::new(Waves::new(wave_args));
        }
    }

    let now = Instant::now();

    let mut frame: u32 = 0;
    while args.frame_cnt == 0 || frame < args.frame_cnt {
        anim.render(frame, &mut fb);
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
