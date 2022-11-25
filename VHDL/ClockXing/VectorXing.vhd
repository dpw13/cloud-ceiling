library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

--* The VectorXing component safely moves correlated data between clock domains. It
--* implements this by registering iData when iPush asserts and sending a pulse across
--* to the OClk domain using the EventXing core. Once the event is seen on the OClk
--* domain, we know that iData has been stable for several OClk cycles and can be
--* safely registered on the OClk domain.
--*
--* @see work.EventXing

--* @brief Clock crossing for a vector of correlated data
entity VectorXing is
  generic (
    --* The width of the data to move between clock domains
    kDataWidth : natural := 32
    );
  port (
    --* The input clock. All i* signals are synchronous to this clock
  IClk : in std_logic;
  --* The data to transmit
  iData : in std_logic_vector(kDataWidth-1 downto 0);
  --* Holdoff for iPush. Asserts if the component is ready for new data
  iReady : out boolean;
  --* Qualifies iData and indicates that iData should be sent to the OClk domain
  iPush : in boolean;

  --* The output clock. All o* signals are synchronous to this clock
  OClk : in std_logic;
  --* The transmitted data
  oData : out std_logic_vector(kDataWidth-1 downto 0);
  --* Asserts for a single cycle when oData has been updated
  oNewData : out boolean
  ) ;
end entity ; -- VectorXing

architecture arch of VectorXing is

  signal iReadyLcl: boolean;
  signal oEvent: boolean;

  signal iDataQ : std_logic_vector(kDataWidth-1 downto 0);

begin

  EventXingx: entity work.EventXing (arch)
    port map (
      IClk   => IClk,       --in  std_logic
      iReady => iReadyLcl,  --out boolean
      iEvent => iPush,      --in  boolean
      OClk   => OClk,       --in  std_logic
      oEvent => oEvent);    --out boolean

  iReady <= iReadyLcl;

  -- We need to register data on the IClk side so we're positive it's stable when
  -- sending to the remote clock domain
  RegData: process(IClk)
  begin
    if rising_edge(IClk) then
      if iReadyLcl and iPush then
        iDataQ <= iData;
      end if;
    end if;
  end process;

  -- Register data on the OClk domain only when we know it's safe to do so. iDataQ
  -- is guaranteed to be stable when oEvent asserts.
  OutData: process(OClk)
  begin
    if rising_edge(OClk) then
      oNewData <= oEvent;
      if oEvent then
        oData <= iDataQ;
      end if;
    end if;
  end process;

end architecture ; -- arch
