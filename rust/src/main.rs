use std::fs;
use std::os::fd::{AsRawFd, RawFd};
use std::cell::RefCell;
use volatile::Volatile;
use nix::ioctl_write_int_bad;
use memmap::{MmapMut, MmapOptions};

pub struct LedDisplay {
    // We use RefCell to retain a reference to the mmap, ensuring that the register space
    // remains accessible. However, we don't ever explicitly reference the mmap again
    // outside of regs, so rust thinks it's dead code.
    #[allow(dead_code)]
    mmap_regs: RefCell<MmapMut>,
    regs: *mut FpgaRegisters,
    fd_fb: RawFd,
    mmap_fb: MmapMut,
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

impl LedDisplay {
    fn new() -> Self {
        const FPGA_REGS_BASE: u64 = 0x1000000;
        const FPGA_REGS_SIZE: usize = 0x2000;
        const FIFO_DATA_SIZE: usize = 0x1000;

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
        let fd_fb = f_fb.as_raw_fd();

        let mmap_fb = unsafe {
            MmapOptions::new()
                        .offset(0)
                        .len(FIFO_DATA_SIZE)
                        .map_mut(&f_fb)
                        .unwrap()
        };

        LedDisplay {mmap_regs, regs, fd_fb, mmap_fb}
    }

    fn read_id(&self) -> u16 {
        unsafe {
            (*self.regs).id.read()
        }
    }

    fn flush(&self) -> () {
        let size : i32 = 0x00;
        unsafe {
            flush_buffer(self.fd_fb, size);
        }
    }
}

fn main() {
    let disp = LedDisplay::new();
    let id = disp.read_id();
    disp.flush();

    println!("FPGA ID: 0x{:x}", id);
}
