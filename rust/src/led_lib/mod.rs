use std::cell::{Cell, RefCell};
use std::fs;
use std::fs::File;
use std::os::fd::{AsRawFd};
use std::thread::sleep;
use std::time::{Duration, Instant};
use memmap::{MmapMut, MmapOptions};
use nix::ioctl_write_int_bad;
use volatile::Volatile;

use crate::constants;

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
pub struct FpgaRegisters {
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

impl LedDisplay {
    pub fn new() -> Self {
        let f_mem = fs::OpenOptions::new().read(true)
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

        // Memory map the ledfb
        let f_fb = fs::OpenOptions::new().read(true)
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
        let wait_time = Cell::new(Duration::from_millis(0));

        LedDisplay {mmap_regs, regs, f_fb, fb_cell, wait_time}
    }

    pub fn read_id(&self) -> u16 {
        unsafe {
            (*self.regs).id.read()
        }
    }

    pub fn empty_count(&self) -> usize {
        unsafe {
            (*self.regs).empty_count.read() as usize
        }
    }

    pub fn flush(&self) -> () {
        let fd = self.f_fb.as_raw_fd();

        let now = Instant::now();
        while self.empty_count() < constants::FRAME_SIZE_WORDS {
            sleep(Duration::from_micros(50));
        }
        self.wait_time.set(self.wait_time.get() + now.elapsed());

        unsafe {
            flush_buffer(fd, constants::FRAME_SIZE_BYTES as i32)
                .expect("IOCTL error");
        }
    }
}
