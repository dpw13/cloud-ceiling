library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library work;
  use work.PkgUtils.all;

--* This component wraps DpRam and stores one additional parity bit for each data
--* word. Even parity is used and stored in the top bit of the RAM at every write.
--* Parity is checked during a read and oDataErr will assert if the total parity
--* is odd at the read port.
--*
--* This component does not verify that an address has been written before being
--* read.

--* @brief A dual-port RAM implementing parity checking
entity DpParityRam is
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
    oDataValid : out boolean;
    --* Asserts if a parity error was detected in the read data
    oDataErr : out boolean
  ) ;
end entity ; -- DpParityRam

architecture arch of DpParityRam is

  signal oParityData: std_logic_vector(kDataWidth downto 0);
  signal iParityData: std_logic_vector(kDataWidth downto 0);

  signal oDataValidLcl: boolean;

  function Parity(I : std_logic_vector) return std_logic is
    variable O : std_logic := '0';
  begin
    for b in I'range loop
      O := O xor I(b);
    end loop ;

    return O;
  end function;

begin

  iParityData(kDataWidth) <= Parity(iData);
  iParityData(kDataWidth-1 downto 0) <= iData;

  DpRamx: entity work.DpRam (arch)
    generic map (
      kLatency   => kLatency,      --natural range 1:2 :=2
      kAddrWidth => kAddrWidth,    --natural:=10
      kDataWidth => kDataWidth+1)  --natural:=32
    port map (
      IClk       => IClk,           --in  std_logic
      iAddr      => iAddr,          --in  unsigned(kAddrWidth-1:0)
      iWr        => iWr,            --in  boolean
      iData      => iParityData,    --in  std_logic_vector(kDataWidth-1:0)
      OClk       => OClk,           --in  std_logic
      oAddr      => oAddr,          --in  unsigned(kAddrWidth-1:0)
      oRd        => oRd,            --in  boolean
      oData      => oParityData,    --out std_logic_vector(kDataWidth-1:0)
      oDataValid => oDataValidLcl); --out boolean

  oData <= oParityData(kDataWidth-1 downto 0);
  -- Data is stored with even parity. When calculating the parity of the RAM
  -- output, the result should always be zero. If it's not, that indicates a
  -- SEU in RAM. Note that we can only detect a single bit flip with this
  -- scheme and we cannot correct any bit flips.
  oDataErr <= oDataValidLcl and to_boolean(Parity(oParityData));
  oDataValid <= oDataValidLcl;

end architecture ; -- arch
