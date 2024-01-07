PROJ = cloud_ceiling
BUILD = ./out
DEVICE = hx4k
FOOTPRNT = tq144

BW_BASE = /home/dwagner/Documents/git/BeagleWire

VER_SRC = \
	Verilog/pll.v \
	Verilog/gpmc_sync.v \
	Verilog/string_driver.v \
	Verilog/extra_strings.v \
	Verilog/parallel_strings.v \
	Verilog/top.v

VER_TB_SRC = Verilog/Testbench/tb_top.v

VHDL_SRC = \
	hdl/VHDL/Packages/PkgUtils.vhd \
	hdl/VHDL/ClockXing/EventXing.vhd \
	hdl/VHDL/ClockXing/VectorXing.vhd \
	hdl/VHDL/Fifo/DpRam.vhd \
	hdl/VHDL/Fifo/DpParityRam.vhd \
	hdl/VHDL/Fifo/FifoCounterHalf.vhd \
	hdl/VHDL/Fifo/SimpleFifo.vhd

TOP_TB_ENT = tb_led_top
TOP_ENT = top

PROJ_FILE = project.yf
PIN_SRC = physical.pcf
PREPACK_PY = timing.py

UVM_VERSION=1800.2-2020-2.0
UVM_FILE_VER=$(shell echo ${UVM_VERSION} | sed -e 's/\.//g')

CCFLAGS=-DQUESTA -Wno-missing-declarations

Q = @

ICECUBE = /opt/lscc/iCEcube2.2020.12

.PHONY: all load clean compile vsim vsimc

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

modelsim/modelsim.mpf:
	mkdir -p modelsim
	cp -f ${MODELSIM_BASE}/modelsim.ini modelsim/modelsim.mpf
	cd modelsim && vlib work && vmap -modelsimini modelsim.mpf work work
	@ # libs are already in ice_vlg lib

deps/uvm/src/uvm_pkg.sv:
	$(eval uvm_tmp := $(shell mktemp))
	$(eval uvm_src := $(shell mktemp -d))
	wget https://www.accellera.org/images/downloads/standards/uvm/UVM-${UVM_FILE_VER}tar.gz -O ${uvm_tmp}
	tar -zxf ${uvm_tmp} -C ${uvm_src}
	rm -rf deps/uvm
	mkdir -p deps
	mv ${uvm_src}/${UVM_VERSION} deps/uvm
	rm -r ${uvm_src}
	rm ${uvm_tmp}

# Note that the order here does matter
modelsim/sources.list: deps/uvm/src/uvm_pkg.sv
	mkdir -p modelsim
	echo ../deps/uvm/src/uvm_pkg.sv > modelsim/sources.list
	echo ../deps/uvm/src/dpi/uvm_dpi.cc >> modelsim/sources.list
	cd modelsim && find ../hdl -name '*.v' >> sources.list
	cd modelsim && find ../hdl -name 'pkg_*.sv' >> sources.list
	cd modelsim && find ../hdl -name '*.sv' | grep -v "/pkg_" >> sources.list

compile: modelsim/sources.list modelsim/modelsim.mpf
	cd modelsim && vlog -modelsimini modelsim.mpf +incdir+../deps/uvm/src -ccflags "${CCFLAGS}" -sv17compat -F sources.list
	cd modelsim && vcom -modelsimini modelsim.mpf $(addprefix "../",${VHDL_SRC})

vsim: compile
	cd modelsim && vsim -modelsimini modelsim.mpf -t ns ${TOP_TB_ENT} +UVM_NO_RELNOTES -L ice_vlg

vsimc: compile
	cd modelsim && vsim -c -modelsimini modelsim.mpf -t ns ${TOP_TB_ENT} +UVM_NO_RELNOTES -L ice_vlg

load:
	sh /home/debian/load-fw/bw-prog.sh $(BUILD)/$(PROJ).bin

clean:
	rm -rf modelsim
	rm -rf $(BUILD)
