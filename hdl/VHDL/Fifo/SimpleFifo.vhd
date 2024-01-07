library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

--* The SimpleFifo component instantiates two FifoCounterHalf components to implement
--* the read and write pointers as well as the dual-port RAM (with parity) to implement
--* the FIFO storage. The component itself contains no logic, just wiring.
--*
--* @see work.DpParityRam, work.FifoCounterHalf

--* @brief A FIFO with parity and configurable width and depth
entity SimpleFifo is
  generic (
    --* The read latency of the FIFO
    kLatency : in natural range 1 to 2 := 2;
    --* Log base 2 of the FIFO depth
    kAddrWidth : in natural := 13;
    --* The width of the data inputs and outputs
    kDataWidth : in natural := 16;
    --* True to use parity RAM, false otherwise
    kUseParity : in boolean := false
    );
  port (
    --* The write clock. All i* signals are sychronous to IClk
    IClk : in std_logic;
    --* Resets the write pointer
    iReset : in boolean;
    --* Data to write to the FIFO
    iData : in std_logic_vector(kDataWidth-1 downto 0);
    --* Write enable
    iWr : in boolean;
    --* The number of writes that can occur before the FIFO is full
    iEmptyCount : out unsigned(kAddrWidth downto 0);
    --* Asserts for one cycle if the FIFO is written while full
    iOverflow : out boolean;

    --* The read clock. All o* signals are sychronous to OClk
    OClk : in std_logic;
    --* Resets the read pointer
    oReset : in boolean;
    --* The data read from the FIFO
    oData : out std_logic_vector(kDataWidth-1 downto 0);
    --* Qualifies oData
    oDataValid : out boolean;
    --* True if a data integrity problem was found in oData
    oDataErr : out boolean;
    --* Read enable
    oRd : in boolean;
    --* The number of valid reads that can occur until the FIFO is empty
    oFullCount : out unsigned(kAddrWidth downto 0);
    --* Asserts for one cycle if the FIFO is read while empty
    oUnderflow : out boolean
  ) ;
end entity ; -- SimpleFifo

architecture arch of SimpleFifo is

  signal iAddr: unsigned(kAddrWidth downto 0);
  signal oAddr: unsigned(kAddrWidth downto 0);

begin

  WriteCounters: entity work.FifoCounterHalf (arch)
    generic map (
      kAddrWidth => kAddrWidth,  --natural
      kWrSide    => true)        --boolean
    port map (
      Clk      => IClk,         --in  std_logic
      cAdvance => iWr,          --in  boolean
      cReset   => iReset,       --in  boolean
      cCount   => iEmptyCount,  --out unsigned(kAddrWidth:0)
      cAddr    => iAddr,        --out unsigned(kAddrWidth:0)
      cErr     => iOverflow,    --out boolean
      RemClk   => OClk,         --in  std_logic
      rAddr    => oAddr);       --in  unsigned(kAddrWidth:0)

  ReadCounters: entity work.FifoCounterHalf (arch)
    generic map (
      kAddrWidth => kAddrWidth,  --natural
      kWrSide    => false)       --boolean
    port map (
      Clk      => OClk,        --in  std_logic
      cAdvance => oRd,         --in  boolean
      cReset   => oReset,      --in  boolean
      cCount   => oFullCount,  --out unsigned(kAddrWidth:0)
      cAddr    => oAddr,       --out unsigned(kAddrWidth:0)
      cErr     => oUnderflow,  --out boolean
      RemClk   => IClk,        --in  std_logic
      rAddr    => iAddr);      --in  unsigned(kAddrWidth:0)

  -- Actual dual-port RAM addresses do not contain the top bit, which is only used for
  -- overflow/underflow detection

  ParityRam: if kUseParity generate
    DpParityRamx: entity work.DpParityRam (arch)
      generic map (
        kLatency   => kLatency,    --natural range 1:2 :=2
        kAddrWidth => kAddrWidth,  --natural:=10
        kDataWidth => kDataWidth)  --natural:=32
      port map (
        IClk       => IClk,                          --in  std_logic
        iAddr      => iAddr(kAddrWidth-1 downto 0),  --in  unsigned(kAddrWidth-1:0)
        iWr        => iWr,                           --in  boolean
        iData      => iData,                         --in  std_logic_vector(kDataWidth-1:0)
        OClk       => OClk,                          --in  std_logic
        oAddr      => oAddr(kAddrWidth-1 downto 0),  --in  unsigned(kAddrWidth-1:0)
        oRd        => oRd,                           --in  boolean
        oData      => oData,                         --out std_logic_vector(kDataWidth-1:0)
        oDataValid => oDataValid,                    --out boolean
        oDataErr   => oDataErr);                     --out boolean
  end generate;

  NoParityRam: if not kUseParity generate
    DpRamx: entity work.DpRam (arch)
      generic map (
        kLatency   => kLatency,    --natural range 1:2 :=2
        kAddrWidth => kAddrWidth,  --natural:=10
        kDataWidth => kDataWidth)  --natural:=32
      port map (
        IClk       => IClk,                          --in  std_logic
        iAddr      => iAddr(kAddrWidth-1 downto 0),  --in  unsigned(kAddrWidth-1:0)
        iWr        => iWr,                           --in  boolean
        iData      => iData,                         --in  std_logic_vector(kDataWidth-1:0)
        OClk       => OClk,                          --in  std_logic
        oAddr      => oAddr(kAddrWidth-1 downto 0),  --in  unsigned(kAddrWidth-1:0)
        oRd        => oRd,                           --in  boolean
        oData      => oData,                         --out std_logic_vector(kDataWidth-1:0)
        oDataValid => oDataValid);                   --out boolean

      oDataErr <= false;
  end generate;

end architecture ; -- arch
