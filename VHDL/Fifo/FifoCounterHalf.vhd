library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

--* The FifoCounterHalf component implements one of the two address pointers needed
--* to implement a FIFO: either the read half or the write half. It advances cAddr
--* every cycle that cAdvance is asserted and calculates the difference between the
--* local and remote pointer (resulting in the full or empty count) and exposes the
--* value in cCount. It moves the remote address across clock domains using a
--* VectorXing.
--*
--* The component implements one additional bit in the address vector than is strictly
--* necessary; the top bit is not used to index the FIFO RAM. That bit allows us to
--* detect error conditions (either over- or under-flows). If the bottom bits match
--* and the top bit matches, that is indicates that the FIFO is empty. This is the
--* initial state of the FIFO because both pointers are initialized to zero. If the
--* bottom bits match but the top bit does not, that indicates that the FIFO is full.
--* This allows us to use all locations in the RAM.
--*
--* @see work.VectorXing

--* @brief Implements the accounting for the read and write FIFO pointers
entity FifoCounterHalf is
  generic (
    --* The width of the physical RAM address pointer
    kAddrWidth : natural := 16;
    --* True if this side implements the write pointer, false otherwise
    kWrSide : boolean := false);
  port (
    --* The local clock. All c* signals are synchronous to Clk
    Clk : in std_logic;
    --* Advances the FIFO pointer by one each cycle this signal asserts
    cAdvance : in boolean;
    --* Resets the FIFO pointer
    cReset : in boolean;
    --* The empty or full count of the FIFO
    cCount : out unsigned(kAddrWidth downto 0);
    --* The full-width FIFO pointer
    cAddr : out unsigned(kAddrWidth downto 0);
    --* Overflow or underflow
    cErr : out boolean;

    --* The remote clock. All r* signals are synchronous to RemClk
    RemClk : in std_logic;
    --* The remote side's FIFO pointer
    rAddr : in unsigned(kAddrWidth downto 0)
  ) ;
end entity ; -- FifoCounterHalf

architecture arch of FifoCounterHalf is

  signal cCountLcl: unsigned(kAddrWidth downto 0);
  signal cAddrLcl, cRemAddr: unsigned(kAddrWidth downto 0) := (others => '0');
  signal cRemAddrSlv: std_logic_vector(kAddrWidth downto 0);

  signal rReady: boolean;

  function SetTopBit(Width : integer)
  return std_logic_vector is
    variable Vector: std_logic_vector(Width-1 downto 0) := (others => '0');
  begin
    Vector(Width-1) := '1';
    return Vector;
  end function;

  constant kTopAddrBit : std_logic_vector(kAddrWidth downto 0) := SetTopBit(kAddrWidth+1);

begin

  VectorXingx: entity work.VectorXing (arch)
    generic map (kDataWidth => kAddrWidth+1)  --natural:=32
    port map (
      IClk     => RemClk,                   --in  std_logic
      iData    => std_logic_vector(rAddr),  --in  std_logic_vector(kDataWidth-1:0)
      iReady   => rReady,                   --out boolean
      iPush    => rReady,                   --in  boolean
      OClk     => Clk,                      --in  std_logic
      oData    => cRemAddrSlv,              --out std_logic_vector(kDataWidth-1:0)
      oNewData => open);                    --out boolean

  WrSide: if kWrSide generate
    -- On the write side the read pointer is effectively halfway through the
    -- address space when both pointers are reset to zero. We define that state
    -- as the FIFO being empty, so the empty count should be 2**kAddrWidth, not
    -- zero. This is implemented by inverting the top bit of the read address when
    -- computing the empty count.
    cRemAddr <= unsigned(cRemAddrSlv xor kTopAddrBit);
  end generate;
  RdSide: if not kWrSide generate
    -- On the read side, having both pointers at zero indicates that the full
    -- count is zero, so the remote address is unmodified.
    cRemAddr <= unsigned(cRemAddrSlv);
  end generate;

    -- Implement the accounting for this side of the FIFO
  FifoCtrl: process(Clk)
    variable cAddrLclNx : unsigned(kAddrWidth downto 0);
  begin
    if rising_edge(Clk) then
      if cReset then
        cAddrLclNx := (others => '0');
      else
        if cAdvance then
          cAddrLclNx := cAddrLcl + 1;
        else
          cAddrLclNx := cAddrLcl;
        end if;
      end if;

      cAddrLcl <= cAddrLclNx;
      -- Count should update the next cycle if cAdvance asserts
      cCountLcl <= cRemAddr - cAddrLclNx;
    end if;
  end process;

  ErrDetect: process(Clk)
  begin
    if rising_edge(Clk) then
      -- Detect under- and over-flows when we attempt to advance when no
      -- data or space is available. Note that this only detects the first
      -- error, not subsequent errors. To do that we could detect advances
      -- if the count was greater than the total FIFO capacity, but I've
      -- opted to omit that since the first error is sufficient to corrupt
      -- data.
      cErr <= cAdvance and (cCountLcl = 0);
    end if;
  end process;

  cCount <= cCountLcl;
  cAddr <= cAddrLcl;

end architecture ; -- arch
