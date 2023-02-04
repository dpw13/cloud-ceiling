use std::fs;
use std::cell::RefCell;
use volatile::Volatile;
use memmap::{MmapMut, MmapOptions};

pub struct LedDisplay {
    // We use RefCell to retain a reference to the mmap, ensuring that the register space
    // remains accessible. However, we don't ever explicitly reference the mmap again
    // outside of regs, so rust thinks it's dead code.
    #[allow(dead_code)]
    mmap: RefCell<MmapMut>,
    regs: *mut FpgaRegisters,
}

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

        let f = fs::OpenOptions::new().read(true)
                                    .write(true)
                                    .open("/dev/mem")
                                    .unwrap();

        // Create a new memory map builder and build a map.
        let mmap = RefCell::new(unsafe {
            MmapOptions::new()
                        .offset(FPGA_REGS_BASE)
                        .len(FPGA_REGS_SIZE)
                        .map_mut(&f)
                        .unwrap()
        });

        let ptr = mmap.borrow_mut().as_mut_ptr();
        let regs = ptr as *mut FpgaRegisters;

        LedDisplay {mmap, regs}
    }

    fn read_id(self) -> u16 {
        unsafe {
            (*self.regs).id.read()
        }
    }
}

fn main() {
    let disp = LedDisplay::new();
    let id = disp.read_id();

    println!("FPGA ID: 0x{:x}", id);
}
