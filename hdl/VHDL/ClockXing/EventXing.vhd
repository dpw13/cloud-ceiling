library ieee;
	use ieee.std_logic_1164.all;
	use ieee.numeric_std.all;

--* The EventXing component safely crosses an event signals between unrelated clock
--* domains. It does this by toggling a flip-flop on the IClk domain every cycle iEvent
--* asserts. That toggle flop is then double-synchronized to the OClk clock domain.
--* An edge detector then drives oEvent, asserting oEvent when a toggle is detected.
--* Another toggle-flop on the OClk domain toggles when an edge is detected on the
--* incoming toggle signal. That is then double-synchronized back to the IClk domain.
--* When the outgoing and incoming toggle flops on the IClk domain match, no events
--* are in flight and the component is ready for iEvent to assert. If the flops do
--* not match, then an event (or toggle or edge) is in flight between clock domains
--* and iEvent should not be asserted or else the pulse will be lost.

--* @brief Clock crossing for single-cycle pulsed signals
entity EventXing is
  port (
  	--* The input clock. All i* signals are synchronous to this clock
	IClk : in std_logic;
	--* Indicates that this component is ready for iEvent to assert again.
	iReady : out boolean;
	--* Asserts for a single cycle to indicate a particular event has occurred.
	iEvent : in boolean;

	--* The output clock. All o* signals are synchronous to this clock
	OClk : in std_logic;
	--* Asserts for a single cycle to indicate that iEvent has asserted.
	oEvent : out boolean
  ) ;
end entity ; -- EventXing

architecture arch of EventXing is

	signal iReadyLcl : boolean := false;

	signal iLclToggle : boolean := false;
	signal iFarToggleMeta, iFarToggle : boolean := false;

	signal oLclToggle : boolean := false;
	signal oFarToggleMeta, oFarToggle, oFarToggleQ : boolean := false;

begin

	-- Toggle our local toggle flop if the incoming event is signaled and
	-- the remote side is ready to accept the event.
	IToggle: process(IClk)
	begin
		if rising_edge(IClk) then
--synthesis translate_off
			assert not (iEvent and not iReadyLcl)
				report "Event occurred before EventXing core was ready"
				severity error;
--synthesis translate_on

			if iReadyLcl and iEvent then
				iLclToggle <= not iLclToggle;
			end if;
		end if;
	end process;

	-- OClk toggle signal is immediately returned to indicate ready. Holdoff
	-- would occur here if we needed to wait for something to happen on the
	-- remote side.
	oLclToggle <= oFarToggle;

	ODblSync: process(OClk)
	begin
		if rising_edge(OClk) then
			oFarToggleMeta <= iLclToggle;
			oFarToggle <= oFarToggleMeta;
			oFarToggleQ <= oFarToggle;
		end if;
	end process;

	IDblSync: process(IClk)
	begin
		if rising_edge(IClk) then
			iFarToggleMeta <= oLclToggle;
			iFarToggle <= iFarToggleMeta;
		end if;
	end process;

	-- The event is observed on the remote side if we saw the toggle signal flip
	oEvent <= oFarToggle /= oFarToggleQ;

	-- The IClk side is ready if the sent and received toggles match
	iReadyLcl <= iFarToggle = iLclToggle;
	iReady <= iReadyLcl;

end architecture ; -- arch
