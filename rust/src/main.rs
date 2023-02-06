use std::fs;
use std::time::{Duration, Instant};
use std::thread::sleep;
use std::fs::File;
use std::os::fd::{AsRawFd};
use std::cell::{Cell, RefCell};
use volatile::Volatile;
use nix::ioctl_write_int_bad;
use memmap::{MmapMut, MmapOptions};

use magick_rust::{magick_wand_genesis, DrawingWand, PixelWand, MagickWand};

pub struct LedDisplay {
    /*
     * We use RefCell to retain a reference to the mmap, ensuring that the register space
     * remains accessible. However, we don't ever explicitly reference the mmap again
     * outside of regs, so rust thinks it's dead code.
     */
    #[allow(dead_code)]
    mmap_regs: RefCell<MmapMut>,

    /* The actual memory-mapped registers as Volatile<u16> */
    regs: *mut FpgaRegisters,

    /* The ledfb device file used for ioctl */
    f_fb: File,

    /* The memory-mapped framebuffer from the kernel */
    pub fb_cell: RefCell<MmapMut>,

    /* The total amount of time spent waiting for the FIFO to flush */
    pub wait_time: Cell<Duration>,
}

const FB_IOC: u32 = 0;
ioctl_write_int_bad!(flush_buffer, FB_IOC);

#[repr(C)]
struct FpgaRegisters {
    id: Volatile<u16>, // 0
    scratch: Volatile<u16>,
    reset_status: Volatile<u16>, // 4
    rsvd0: Volatile<u16>,
    rsvd1: Volatile<u16>, // 8
    rsvd2: Volatile<u16>,
    rsvd3: Volatile<u16>, // C
    rsvd4: Volatile<u16>,
    fifo_status: Volatile<u16>, // 0x10
    empty_count: Volatile<u16>, // 0x12
    blank: Volatile<u16>, // 0x14
}

const FPGA_REGS_BASE: u64 = 0x1000000;
const FPGA_REGS_SIZE: usize = 0x2000;
const FIFO_DATA_SIZE: usize = 0x4000;

/* Needs to match FPGA to get correct framebuffer size. */
const LED_COUNT: u32 = 118;
const STRING_COUNT: u32 = 24;
const BYTES_PER_LED: u32 = 3;

const FRAME_SIZE_BYTES: usize = (LED_COUNT*STRING_COUNT*BYTES_PER_LED) as usize;
const FRAME_SIZE_WORDS: usize = FRAME_SIZE_BYTES / 2;

impl LedDisplay {
    fn new() -> Self {
        let f_mem = fs::OpenOptions::new().read(true)
                                    .write(true)
                                    .open("/dev/mem")
                                    .unwrap();

        // Create a new memory map builder and build a map for the registers.
        let mmap_regs = RefCell::new(unsafe {
            MmapOptions::new()
                        .offset(FPGA_REGS_BASE)
                        .len(FPGA_REGS_SIZE)
                        .map_mut(&f_mem)
                        .unwrap()
        });

        let ptr = mmap_regs.borrow_mut().as_mut_ptr();
        let regs = ptr as *mut FpgaRegisters;

        // Memory map the ledfb
        let f_fb = fs::OpenOptions::new().read(true)
                                    .write(true)
                                    .open("/dev/ledfb")
                                    .unwrap();

        let mmap_fb = unsafe {
            MmapOptions::new()
                        .offset(0)
                        .len(FIFO_DATA_SIZE)
                        .map_mut(&f_fb)
                        .unwrap()
        };

        let fb_cell = RefCell::new(mmap_fb);
        let wait_time = Cell::new(Duration::from_millis(0));

        LedDisplay {mmap_regs, regs, f_fb, fb_cell, wait_time}
    }

    fn read_id(&self) -> u16 {
        unsafe {
            (*self.regs).id.read()
        }
    }

    fn empty_count(&self) -> usize {
        unsafe {
            (*self.regs).empty_count.read() as usize
        }
    }

    fn flush(&self) -> () {
        let fd = self.f_fb.as_raw_fd();

        let now = Instant::now();
        while self.empty_count() < FRAME_SIZE_WORDS {
            sleep(Duration::from_millis(1));
        }
        self.wait_time.set(self.wait_time.get() + now.elapsed());

        unsafe {
            let res = flush_buffer(fd, FRAME_SIZE_BYTES as i32);
            match res {
                Err(err) => panic!("IOCTL error: {:?}", err),
                Ok(_) => ()
            };
        }
    }
}

fn main() {
    // Initialize magick-wand
    magick_wand_genesis();

    let disp = LedDisplay::new();
    let id = disp.read_id();

    println!("FPGA ID: 0x{:x}", id);
    println!("Starting empty count: {}", disp.empty_count());

    let mut mut_fb = disp.fb_cell.borrow_mut();
    let fb = match mut_fb.get_mut(0..FRAME_SIZE_BYTES) {
        None => panic!("Could not get framebuffer reference to {} B", FRAME_SIZE_BYTES),
        Some(x) => x,
    };

    let mut wand = MagickWand::new();
    let mut draw = DrawingWand::new();

    let mut bg = PixelWand::new();
    match bg.set_color("rgb(0,0,0)") {
        Err(err) => panic!("Could not set color: {:?}", err),
        Ok(_) => (),
    };

    let mut draw_time = Duration::from_millis(0);
    let mut render_time = Duration::from_millis(0);
    let mut copy_time = Duration::from_millis(0);

    let now = Instant::now();
    for frame in 0..99 {
        let r = (frame + 0) % 24;
        let b = (frame + 8) % 24;
        let g = (frame + 16) % 24;
        let color_str = format!("rgb({},{},{})", r, b, g);
        match bg.set_color(&color_str) {
            Err(err) => panic!("Could not set color: {:?}", err),
            Ok(_) => (),
        };

        // Create new image. There isn't a good way to clear the existing image, so just create a new one.
        match wand.new_image(STRING_COUNT as usize, LED_COUNT as usize, &bg) {
            Err(err) => panic!("Could create new image: {:?}", err),
            Ok(_) => (),
        }

        // the `clear` methods are marked private. We do this ugly hack to call the actual
        // bound clear function on the internal struct (which fortunately is public).
        unsafe {magick_rust::bindings::ClearDrawingWand(draw.wand)};

        // Drawing code here
        draw.set_fill_color(&bg);
        draw.draw_rectangle(0.0, 0.0, 1.0, 1.0);

        // Render
        let draw_start = Instant::now();
        match wand.draw_image(&draw) {
            Err(err) => panic!("Could not draw image: {:?}", err),
            Ok(_) => (),
        };

        // Export pixels in framebuffer format
        let export_start = Instant::now();
        let img_data = &match wand.export_image_pixels(0, 0, STRING_COUNT as usize, LED_COUNT as usize, "BRG") {
            None => panic!("Could not export pixels"),
            Some(vec) => vec,
        };
        let copy_start = Instant::now();
        // Copy to kernel buffer
        fb.copy_from_slice(img_data);
        let copy_end = Instant::now();

        draw_time += export_start - draw_start;
        render_time += copy_start - export_start;
        copy_time += copy_end - copy_start;

        // Call ioctl to DMA to hardware
        disp.flush();

        // Cleanup before next frame
        unsafe {magick_rust::bindings::MagickRemoveImage(wand.wand)};
    }

    println!("100 frames in {:?}. Spent {:?} in flush.", now.elapsed(), disp.wait_time.get());
    println!("Spent {:?} in draw, {:?} in export, {:?} in copy", draw_time, render_time, copy_time);

    // Blank
    mut_fb.fill(0);
    disp.flush();
    // Wait for DMA to finish. Otherwise the last blank frame doesn't get flushed.
    sleep(Duration::from_millis(5));

    while disp.empty_count() < 8000 {
        sleep(Duration::from_millis(1));
    }
    println!("Ending empty count: {}", disp.empty_count());
}
