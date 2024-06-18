use memmap::{MmapMut, MmapOptions};
use nix::ioctl_write_int_bad;
use std::cell::{Cell, RefCell, RefMut};
use std::fs;
use std::fs::File;
use std::os::fd::AsRawFd;
use std::ptr::{read_volatile, write_volatile};
use std::thread::sleep;
use std::time::{Duration, Instant};

use crate::constants;

pub struct LedRegs {
    /*
     * We use RefCell to retain a reference to the mmap, ensuring that the register space
     * remains accessible. However, we don't ever explicitly reference the mmap again
     * outside of regs, so rust thinks it's dead code.
     */
    #[allow(dead_code)]
    mmap_regs: RefCell<MmapMut>,

    /* The actual memory-mapped registers as u16 */
    pub regs: *mut FpgaRegisters,
}

unsafe impl Send for LedRegs {}
unsafe impl Sync for LedRegs {}

pub struct LedFramebuffer {
    /* The ledfb device file used for ioctl */
    f_fb: File,

    /* The memory-mapped framebuffer from the kernel */
    pub fb_cell: RefCell<MmapMut>,
}

pub struct LedDisplay {
    regs: LedRegs,
    fb: LedFramebuffer,

    /* The total amount of time spent waiting for the FIFO to flush */
    pub wait_time: Cell<Duration>,
}

const FB_IOC: u32 = 0;
ioctl_write_int_bad!(flush_buffer, FB_IOC);

#[repr(C)]
pub struct FpgaRegisters {
    id: u16, // 0
    scratch: u16,
    reset_status: u16, // 4
    rsvd0: [u16;5],
    fifo_status: u16, // 0x10
    empty_count: u16, // 0x12
    rsvd1: [u16;6],
    white_led: u32,   // 0x20
}

impl LedRegs {
    pub fn new() -> Self {
        let f_mem = fs::OpenOptions::new()
            .read(true)
            .write(true)
            .open("/dev/mem")
            .unwrap();

        // Create a new memory map builder and build a map for the registers.
        let mmap_regs = RefCell::new(unsafe {
            MmapOptions::new()
                .offset(constants::FPGA_REGS_BASE)
                .len(constants::FPGA_REGS_SIZE)
                .map_mut(&f_mem)
                .expect("Failed to mmap register region")
        });

        let regs = mmap_regs.borrow_mut().as_mut_ptr() as *mut FpgaRegisters;

        LedRegs { mmap_regs, regs }
    }

    pub fn read_id(&self) -> u16 {
        unsafe { read_volatile(&(*self.regs).id) }
    }

    pub fn empty_count(&self) -> usize {
        unsafe { read_volatile(&(*self.regs).empty_count) as usize }
    }

    pub fn set_white_led(&self, cold: u8, cool: u8, hot: u8) -> () {
        let value = (cold as u32) << 8 | (cool as u32) | (hot as u32) << 16;
        //print!("cold {cold} cool {cool} hot {hot} val 0x{value:06x}\n");
        unsafe { write_volatile(&mut (*self.regs).white_led, value) }
    }

    pub fn set_white_led_f32(&self, cold: f32, cool: f32, hot: f32) -> () {
        const LED_MAX: f32 = 127.0; // MSB being ignored? TODO
        let x = (cold * LED_MAX).round().clamp(0.0, LED_MAX) as u8;
        let y = (cool * LED_MAX).round().clamp(0.0, LED_MAX) as u8;
        let z = (hot * LED_MAX).round().clamp(0.0, LED_MAX) as u8;
        self.set_white_led(x, y, z)
    }
}

impl LedFramebuffer {
    pub fn new() -> Self {
        // Memory map the ledfb
        let f_fb = fs::OpenOptions::new()
            .read(true)
            .write(true)
            .open("/dev/ledfb")
            .expect("Could not open LED framebuffer device");

        let mmap_fb = unsafe {
            MmapOptions::new()
                .offset(0)
                .len(constants::FIFO_DATA_SIZE)
                .map_mut(&f_fb)
                .expect("Failed to mmap framebuffer")
        };

        let fb_cell = RefCell::new(mmap_fb);

        LedFramebuffer {
            f_fb,
            fb_cell,
        }
    }


    // MmapMut has same lifetime as LedDisplay
    pub fn borrow_fb<'a>(&'a self) -> RefMut<[u8]> {
        let mut_fb = self.fb_cell.borrow_mut();
        let (begin, mut _end) = RefMut::map_split(mut_fb, |slice| {
            slice.split_at_mut(constants::FRAME_SIZE_BYTES)
        });

        begin
    }

    pub fn flush(&self) -> () {
        let fd = self.f_fb.as_raw_fd();

        unsafe {
            flush_buffer(fd, constants::FRAME_SIZE_BYTES as i32).expect("IOCTL error");
        }
    }
}

impl LedDisplay {
    pub fn new() -> Self {
        let wait_time = Cell::new(Duration::from_millis(0));

        LedDisplay {
            regs: LedRegs::new(),
            fb: LedFramebuffer::new(),
            wait_time,
        }
    }

    pub fn read_id(&self) -> u16 {
        self.regs.read_id()
    }

    pub fn empty_count(&self) -> usize {
        self.regs.empty_count()
    }

    pub fn borrow_fb<'a>(&'a self) -> RefMut<[u8]> {
        self.fb.borrow_fb()
    }

    pub fn flush(&self) -> () {
        // TODO: Remove me once FIFO overruns are resolved
        sleep(Duration::from_millis(2));

        let now = Instant::now();
        while self.regs.empty_count() < constants::FRAME_SIZE_WORDS {
            sleep(Duration::from_micros(50));
        }
        self.wait_time.set(self.wait_time.get() + now.elapsed());
        self.fb.flush();
    }
}
