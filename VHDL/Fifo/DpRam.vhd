library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

--* Does what it says on the tin.

--* @brief A true dual-port RAM with one read port and one write port of the same width
entity DpRam is
  generic (
    --* The read latency of the RAM
    kLatency : natural range 1 to 2 := 2;
    --* The width of the address pointers
    kAddrWidth : natural := 10;
    --* The width of the RAM data
    kDataWidth : natural := 32
    );
  port (
    --* The write clock. All i* signals are synchronous to IClk
    IClk : in std_logic;
    --* The write pointer
    iAddr : in unsigned(kAddrWidth-1 downto 0);
    --* Write enable
    iWr : in boolean;
    --* Data to be written
    iData : in std_logic_vector(kDataWidth-1 downto 0);

    --* The read clock. All o* signals are synchronous to OClk
    OClk : in std_logic;
    --* The read pointer
    oAddr : in unsigned(kAddrWidth-1 downto 0);
    --* Read enable
    oRd : in boolean;
    --* The data read
    oData : out std_logic_vector(kDataWidth-1 downto 0);
    --* Qualifier for oData; asserts kLatency cycles after oRd
    oDataValid : out boolean
  ) ;
end entity ; -- DpRam

architecture arch of DpRam is

  type DataArray_t is array(natural range <>) of std_logic_vector(kDataWidth-1 downto 0);
  signal Ram : DataArray_t(2**kAddrWidth-1 downto 0); 

  signal oDataPipe : DataArray_t(kLatency-1 downto 0) := (others => (others => '0'));

  type BooleanVector_t is array(natural range <>) of boolean;
  signal oRdPipe : BooleanVector_t(kLatency-1 downto 0) := (others => false);

begin

  WrProc: process(IClk)
  begin
    if rising_edge(IClk) then
      if iWr then
        RAM(to_integer(unsigned(iAddr))) <= iData;
      end if;
    end if;
  end process;

  RdProc: process(OClk)
  begin
    if rising_edge(OClk) then
      -- Reads occur constantly. There are some power savings to be had by powering down
      -- the read side of RAMs, but I haven't implemented that here. The DataValid output
      -- is provided for convenience for indicating the latency of the RAM.
      oRdPipe(kLatency-1) <= oRd;
      oDataPipe(kLatency-1) <= RAM(to_integer(unsigned(oAddr)));
    end if;
  end process;

  OutputFlops: if kLatency > 1 generate
    process(OClk)
    begin
      if rising_edge(OClk) then
        -- Only implement these flops if the latency is greater than 1. Otherwise this
        -- is a null statement and that has often caused problems with synthesizers in
        -- the past.
        oRdPipe(kLatency-2 downto 0) <= oRdPipe(kLatency-1 downto 1);
        oDataPipe(kLatency-2 downto 0) <= oDataPipe(kLatency-1 downto 1);
      end if;
    end process;
  end generate;

  oData <= oDataPipe(0);
  oDataValid <= oRdPipe(0);

end architecture ; -- arch
