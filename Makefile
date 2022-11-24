PROJ = blink
BUILD = ./out
DEVICE = hx4k
FOOTPRNT = tq144

BW_BASE = /home/dwagner/Documents/git/BeagleWire

SRC = top.v
SRC += gpmc-sync.v
TOP_SRC = top
PIN_SRC = physical.pcf
PREPACK_PY = timing.py

Q = @

.PHONY: all load clean

all: $(BUILD)/$(PROJ).bin

${BUILD}/${PROJ}.synth.json : ${SRC}
	@ echo -n "Synthesis ... "
	@ mkdir -p $(BUILD)
	@ yosys -q -p "synth_ice40 -top ${TOP_SRC} -json $(BUILD)/$(PROJ).synth.json" $(SRC)
	@ echo " Done"

${BUILD}/${PROJ}.asc : ${BUILD}/${PROJ}.synth.json ${PIN_SRC} ${PREPACK_PY}
	@ echo -n "Place & Route ... "
	@ nextpnr-ice40 -q --top ${TOP_SRC} --$(DEVICE) --package $(FOOTPRNT) --pre-pack ${PREPACK_PY} --pcf $(PIN_SRC) --asc $(BUILD)/$(PROJ).asc --json $(BUILD)/$(PROJ).synth.json --report ${BUILD}/${PROJ}.rpt.json
	@ echo " Done"
	@ # nextpnr does timing analysis internally, report results
	@ echo
	@ ./print_report.py ${BUILD}/${PROJ}.rpt.json
	@ echo

$(BUILD)/$(PROJ).bin : $(BUILD)/$(PROJ).asc
	@ echo -n "Pack ... "
	@ icepack $(BUILD)/$(PROJ).asc $(BUILD)/$(PROJ).bin
	@ echo -e "\x0\x0\x0\x0\x0\x0\x0" >> $(BUILD)/$(PROJ).bin
	@ echo " Done"

load:
	sh /home/debian/load-fw/bw-prog.sh $(BUILD)/$(PROJ).bin

clean:
	rm -rf $(BUILD)
