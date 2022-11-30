PROJ = cloud_ceiling
BUILD = ./out
DEVICE = hx4k
FOOTPRNT = tq144

BW_BASE = /home/dwagner/Documents/git/BeagleWire

VER_SRC = \
	Verilog/pll.v \
	Verilog/gpmc_sync.v \
	Verilog/string_driver.v \
	Verilog/top.v

VER_TB_SRC = Verilog/Testbench/tb_top.v

VHDL_SRC = \
	VHDL/Fifo/RedundantFifo.vhd \
	VHDL/Fifo/FifoCounterHalf.vhd \
	VHDL/Fifo/DpRam.vhd \
	VHDL/Fifo/SimpleFifo.vhd \
	VHDL/Fifo/DpParityRam.vhd \
	VHDL/ClockXing/VectorXing.vhd \
	VHDL/ClockXing/EventXing.vhd \
	VHDL/Packages/PkgUtils.vhd

TOP_TB_ENT = tb_top
TOP_ENT = top

PROJ_FILE = project.yf
PIN_SRC = physical.pcf
PREPACK_PY = timing.py

Q = @

ICECUBE = /opt/lscc/iCEcube2.2020.12

.PHONY: all load clean build_libs sim vsim

all: $(BUILD)/$(PROJ).bin

${BUILD}/${PROJ}.synth.json : ${VER_SRC} ${VHDL_SRC} ${PROJ_FILE}
	@ echo -n "Synthesis ... "
	@ mkdir -p $(BUILD)
	@ yosys -m ghdl -s ${PROJ_FILE}
	@ echo " Done"

${BUILD}/${PROJ}.asc : ${BUILD}/${PROJ}.synth.json ${PIN_SRC} ${PREPACK_PY}
	@ echo -n "Place & Route ... "
	@ nextpnr-ice40 -q --top ${TOP_ENT} --$(DEVICE) --package $(FOOTPRNT) --pre-pack ${PREPACK_PY} --pcf $(PIN_SRC) --asc $(BUILD)/$(PROJ).asc --json $(BUILD)/$(PROJ).synth.json --report ${BUILD}/${PROJ}.rpt.json
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

build_libs:
	mkdir -p modelsim
	cp -f ${MODELSIM}/modelsim.ini modelsim/modelsim.mpf
	cd modelsim && vlib work && vmap -modelsimini modelsim.mpf work work
	@ # libs are already in ice_vlg lib

sim:
	cd modelsim && vlog -modelsimini modelsim.mpf $(addprefix ../, ${VER_SRC}) ../out/SimpleFifo.v $(addprefix ../, ${VER_TB_SRC})

vsim:
	cd modelsim && vsim -modelsimini modelsim.mpf -t ns ${TOP_TB_ENT} -L ice_vlg

vsimc:
	cd modelsim && vsim -c -modelsimini modelsim.mpf -t ns ${TOP_TB_ENT} -L ice_vlg

load:
	sh /home/debian/load-fw/bw-prog.sh $(BUILD)/$(PROJ).bin

clean:
	rm -rf modelsim
	rm -rf $(BUILD)
