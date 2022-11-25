library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

--* The RedundantFifo component works exactly like the SimpleFifo except that it instantiates two
--* parallel parity RAMs. The output read data is selected from either RAM based on whether the
--* data exhibited a parity error or not. This allows us to recover from a single bit error in
--* the read data. This still does not allow us to detect two bit errors like more advanced data
--* integrity algorithms will, but it is fast and simple at the cost of additional RAM.
--*
--* @see work.SimpleFifo, work.DpParityRam, work.FifoCounterHalf

--* @brief A FIFO capable of recovering from a SEU in RAM with configurable width and depth
entity RedundantFifo is
  generic (
    --* The read latency of the FIFO
    kLatency : in natural range 1 to 2;
    --* The width of the data inputs and outputs
    kDataWidth : in natural;
    --* Log base 2 of the FIFO depth
    kAddrWidth : in natural
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
end entity ; -- RedundantFifo

architecture arch of RedundantFifo is

  signal iAddr: unsigned(kAddrWidth downto 0);
  signal oAddr: unsigned(kAddrWidth downto 0);
  signal oDataA: std_logic_vector(kDataWidth-1 downto 0);
  signal oDataB: std_logic_vector(kDataWidth-1 downto 0);
  signal oDataErrA: boolean;
  signal oDataErrB: boolean;

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

  ParityRamA: entity work.DpParityRam (arch)
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
      oData      => oDataA,                        --out std_logic_vector(kDataWidth-1:0)
      oDataValid => oDataValid,                    --out boolean
      oDataErr   => oDataErrA);                    --out boolean

  ParityRamB: entity work.DpParityRam (arch)
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
      oData      => oDataB,                        --out std_logic_vector(kDataWidth-1:0)
      oDataValid => open,                          --out boolean
      oDataErr   => oDataErrB);                    --out boolean

  oData <= oDataA when not oDataErrA else oDataB;
  oDataErr <= oDataErrA and oDataErrB;

end architecture ; -- arch
