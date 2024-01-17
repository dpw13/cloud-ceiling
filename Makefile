PROJ = cloud_ceiling
BUILD = ./out
DEVICE = hx4k
FOOTPRNT = tq144

BW_BASE = /home/dwagner/Documents/git/BeagleWire

SV_SRC = \
	hdl/pkg_cpu_if.sv \
	hdl/gpmc_sync.sv \
	hdl/cloud_ceiling_regmap_wrapper.sv \
	hdl/top.sv

GEN_SRC = \
	deps/gen/cloud_ceiling_regmap_pkg.sv \
	deps/gen/cloud_ceiling_regmap.sv

VER_SRC = \
	hdl/pll.v \
	hdl/string_driver.v \
	hdl/extra_strings.v \
	hdl/parallel_strings.v

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
VLOGFLAGS=+define+UVM_REG_DATA_WIDTH=256

Q = @

ICECUBE = /opt/lscc/iCEcube2.2020.12

.PHONY: all load clean compile vsim vsimc

all: $(BUILD)/$(PROJ).bin

${BUILD}/${PROJ}.synth.json : ${SV_SRC} ${VER_SRC} ${VHDL_SRC} ${GEN_SRC} ${PROJ_FILE}
	$(Q) echo "Synthesis ... "
	$(Q) mkdir -p $(BUILD)
	$(Q) ghdl -a ${VHDL_SRC}
	$(Q) yosys -s ${PROJ_FILE}
	$(Q) echo " Done"

${BUILD}/${PROJ}.asc : ${BUILD}/${PROJ}.synth.json ${PIN_SRC} ${PREPACK_PY}
	$(Q) echo -n "Place & Route ... "
	$(Q) nextpnr-ice40 --top ${TOP_ENT} --$(DEVICE) --package $(FOOTPRNT) --pre-pack ${PREPACK_PY} --pcf $(PIN_SRC) --asc $(BUILD)/$(PROJ).asc --json $(BUILD)/$(PROJ).synth.json --report ${BUILD}/${PROJ}.rpt.json
	$(Q) echo " Done"
	$(Q) # nextpnr does timing analysis internally, report results
	$(Q) echo
	$(Q) ./print_report.py ${BUILD}/${PROJ}.rpt.json
	$(Q) echo

$(BUILD)/$(PROJ).bin : $(BUILD)/$(PROJ).asc
	$(Q) echo -n "Pack ... "
	$(Q) icepack $(BUILD)/$(PROJ).asc $(BUILD)/$(PROJ).bin
	$(Q) echo -e "\x0\x0\x0\x0\x0\x0\x0" >> $(BUILD)/$(PROJ).bin
	$(Q) echo " Done"

modelsim/modelsim.mpf:
	$(Q) mkdir -p modelsim
	$(Q) cp -f ${MODELSIM_BASE}/modelsim.ini modelsim/modelsim.mpf
	$(Q) cd modelsim && vlib work && vmap -modelsimini modelsim.mpf work work
	$(Q) # libs are already in ice_vlg lib

deps/uvm/src/uvm_pkg.sv:
	$(eval uvm_tmp := $(shell mktemp))
	$(eval uvm_src := $(shell mktemp -d))
	$(Q) wget https://www.accellera.org/images/downloads/standards/uvm/UVM-${UVM_FILE_VER}tar.gz -O ${uvm_tmp}
	$(Q) tar -zxf ${uvm_tmp} -C ${uvm_src}
	$(Q) rm -rf deps/uvm
	$(Q) mkdir -p deps
	$(Q) mv ${uvm_src}/${UVM_VERSION} deps/uvm
	$(Q) rm -r ${uvm_src}
	$(Q) rm ${uvm_tmp}

deps/gen/pkg_cloud_ceiling_regmap.sv: docs/regs.rdl
	$(Q) mkdir -p deps/gen
	$(Q) peakrdl uvm $? -o $@

deps/gen/cloud_ceiling_regmap.sv: docs/regs.rdl
	$(Q) peakrdl regblock --cpuif passthrough $? -o deps/gen

# Note that the order here does matter
modelsim/sources.list: deps/uvm/src/uvm_pkg.sv deps/gen/pkg_cloud_ceiling_regmap.sv deps/gen/cloud_ceiling_regmap.sv
	$(Q) mkdir -p modelsim
	$(Q) echo ../deps/uvm/src/uvm_pkg.sv > modelsim/sources.list
	$(Q) echo ../deps/uvm/src/dpi/uvm_dpi.cc >> modelsim/sources.list
	$(Q) echo ../deps/gen/pkg_cloud_ceiling_regmap.sv >> modelsim/sources.list
	$(Q) echo ../deps/gen/cloud_ceiling_regmap.sv >> modelsim/sources.list
	$(Q) echo ../deps/gen/cloud_ceiling_regmap_pkg.sv >> modelsim/sources.list

	$(Q) cd modelsim && find ../hdl -name '*.v' >> sources.list
	$(Q) cd modelsim && find ../hdl -name 'pkg_*.sv' >> sources.list
	$(Q) cd modelsim && find ../hdl -name '*.sv' | grep -v "/pkg_" >> sources.list

compile: modelsim/sources.list modelsim/modelsim.mpf
	$(Q) cd modelsim && vlog -modelsimini modelsim.mpf +incdir+../deps/uvm/src ${VLOGFLAGS} -ccflags "${CCFLAGS}" -sv17compat -F sources.list
	$(Q) cd modelsim && vcom -modelsimini modelsim.mpf $(addprefix "../",${VHDL_SRC})

vsim: compile
	$(Q) cd modelsim && vsim -modelsimini modelsim.mpf -t ns ${TOP_TB_ENT} +UVM_NO_RELNOTES -L ice_vlg

vsimc: compile
	$(Q) cd modelsim && vsim -c -modelsimini modelsim.mpf -t ns ${TOP_TB_ENT} +UVM_NO_RELNOTES -L ice_vlg

load:
	sh /home/debian/load-fw/bw-prog.sh $(BUILD)/$(PROJ).bin

clean:
	rm -rf modelsim
	rm -rf $(BUILD)
