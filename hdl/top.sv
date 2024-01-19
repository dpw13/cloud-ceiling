/*
 * Top-level module for cloud ceiling.
 */

module top#(
	// Production params
	parameter int N_COLOR_STRINGS = 23,
	parameter int N_WHITE_STRINGS = 4,
	parameter int N_COLOR_LEDS_PER_STRING = 236,
	parameter int N_WHITE_LEDS_PER_STRING = 118
) (
	input wire clk_100,
	input wire glbl_reset,

	output wire [3:0] led,

	// GPMC INTERFACE
	inout wire [15:0] gpmc_ad,
	input wire        gpmc_advn,
	input wire        gpmc_csn1,
	input wire        gpmc_wein,
	input wire        gpmc_oen,
	input wire        gpmc_clk,

	// LED string interface
	output wire [22:0]  color_led_sdi,
	output wire [3:0]  white_led_sdi
);

	import cloud_ceiling_regmap_pkg::*;
	import pkg_cpu_if::*;

	localparam GPMC_ADDR_WIDTH = 16;
	localparam GPMC_DATA_WIDTH = 16;
	localparam FIFO_ADDR_WIDTH = 13;
	localparam FIFO_DATA_WIDTH = 16;

	// Testbench params
	//localparam N_COLOR_STRINGS = 5;
	//localparam N_WHITE_STRINGS = 2;
	//localparam N_COLOR_LEDS_PER_STRING = 24;
	//localparam N_WHITE_LEDS_PER_STRING = 24;

	wire clk_20;
	wire pll_locked;

	pll system_pll (
		.reset_n(~glbl_reset),
		.clock_in(clk_100),
		.clock_out(clk_20),
		.locked(pll_locked)
	);

	logic reset_ms_100 = 1'b1;
	logic reset_100 = 1'b1;
	always @(posedge clk_100)
	begin
		// Double-sync reset onto clk_100
		reset_ms_100 <= glbl_reset;
		reset_100 <= reset_ms_100;
	end

	logic reset_ms_20 = 1'b1;
	logic reset_20 = 1'b1;
	always @(posedge clk_20)
	begin
		// Double-sync reset onto clk_20
		// Note that this isn't really safe because the combinatorial input to the metastable flop.
		reset_ms_20 <= ~pll_locked || glbl_reset;
		reset_20 <= reset_ms_20;
	end

	// Light LED[1] when there's a GPMC transaction
	assign led[1] = ~gpmc_csn1;

	wire cpu_if_i cpuif_i;
	wire cpu_if_o cpuif_o;

	gpmc_sync # (
		.ADDR_WIDTH(GPMC_ADDR_WIDTH),
		.DATA_WIDTH(GPMC_DATA_WIDTH)
	) gpmc_sync_impl (
		// GPMC INTERFACE
		.gpmc_clk(gpmc_clk),
		.gpmc_ad(gpmc_ad),
		.gpmc_adv_n(gpmc_advn),
		.gpmc_cs_n(gpmc_csn1),
		.gpmc_we_n(gpmc_wein),
		.gpmc_oe_n(gpmc_oen),

		// HOST INTERFACE
		.clk(clk_100),
		.reset(reset_100),
		.cpuif_i(cpuif_i),
		.cpuif_o(cpuif_o)
	);

    wire cloud_ceiling_regmap__in_t hwif_in;
    wire cloud_ceiling_regmap__out_t hwif_out;

    cloud_ceiling_regmap_wrapper regmap (
        .clk(clk_100),
        .reset(reset_100),
		.cpuif_i(cpuif_i),
		.cpuif_o(cpuif_o),

        .hwif_in(hwif_in),
        .hwif_out(hwif_out)
    );

	logic       fifo_overflow;
	logic       fifo_underflow;
	logic [FIFO_ADDR_WIDTH:0] fifo_empty_count;

	assign hwif_in.REGS.RESET_STATUS_REG.RESET_100.next = reset_100;
	assign hwif_in.REGS.RESET_STATUS_REG.RESET_20.next = reset_20;
	assign hwif_in.REGS.FIFO_STATUS_REG.UNDERFLOW.hwset = fifo_overflow;
	assign hwif_in.REGS.FIFO_STATUS_REG.OVERFLOW.hwset = fifo_underflow;
	assign hwif_in.REGS.FIFO_EMPTY_REG.COUNT.next = fifo_empty_count;

	assign hwif_in.FIFO_MEM.rd_data = '0;

	logic rd_ack, wr_ack;

	always_ff @(posedge clk_100) begin
		if(reset_100) begin
			rd_ack <= 1'b0;
			wr_ack <= 1'b0;
		end else begin
			rd_ack <= hwif_out.FIFO_MEM.req && !hwif_out.FIFO_MEM.req_is_wr;
			wr_ack <= hwif_out.FIFO_MEM.req &&  hwif_out.FIFO_MEM.req_is_wr;
		end
	end

	assign hwif_in.FIFO_MEM.rd_ack = rd_ack;
	assign hwif_in.FIFO_MEM.wr_ack = wr_ack;

	logic white_value_valid;
	logic [23:0] white_value_in; // Cold Red Warm

	assign white_value_in = {
		hwif_out.REGS.WHITE_COLOR_H_REG.VALUE.value,
		hwif_out.REGS.WHITE_COLOR_L_REG.VALUE.value};
	assign white_value_valid = hwif_out.REGS.WHITE_COLOR_H_REG.VALUE.swmod;

	logic color_fifo_write;
	logic [15:0] color_fifo_write_data;
	// Anything in the second page will write to the FIFO
	assign color_fifo_write = (hwif_out.FIFO_MEM.req && hwif_out.FIFO_MEM.req_is_wr);
	assign color_fifo_write_data = hwif_out.FIFO_MEM.wr_data;

	logic fifo_toggle = 1'b0;
	always @(posedge clk_100)
	begin
		if (color_fifo_write)
			fifo_toggle <= ~fifo_toggle;
	end

	assign led[2] = fifo_toggle;

	wire        pxl_fifo_read;
	wire [FIFO_ADDR_WIDTH:0]   pxl_fifo_full_count; // Full count is one bit wider than kAddrWidth
	wire [FIFO_DATA_WIDTH-1:0] pxl_fifo_data;
	wire        pxl_fifo_data_valid;
	wire        pxl_fifo_underflow;

	simple_fifo # (
		.DATA_WIDTH(16),
		.ADDR_WIDTH(13)
	) pixel_fifo (
		.iclk(clk_100),
		.ireset(reset_100),
		.idata(color_fifo_write_data),
		.iwr(color_fifo_write),
		.iempty_count(fifo_empty_count),
		.ioverflow(fifo_overflow),

		.oclk(clk_20),
		.oreset(reset_20),
		.odata(pxl_fifo_data),
		.odata_valid(pxl_fifo_data_valid),
		.ord(pxl_fifo_read),
		.ofull_count(pxl_fifo_full_count),
		.ounderflow(pxl_fifo_underflow)
	);

	// Bring the underflow status back to the GPMC clock domain
	event_xing underflow_xing (
		.ireset(reset_20),
		.iclk(clk_20),
		.iready(),
		.ievent(pxl_fifo_underflow),
		.oreset(reset_100),
		.oclk(clk_100),
		.oevent(fifo_underflow)
	);

	// Bring color_valid bit to clk_20
	wire white_value_valid_20;
	event_xing white_value_valid_xing (
		.ireset(reset_100),
		.iclk(clk_100),
		.iready(),
		.ievent(white_value_valid),
		.oreset(reset_20),
		.oclk(clk_20),
		.oevent(white_value_valid_20)
	);

	// String drivers
	parallel_strings #(
		.N_STRINGS(N_COLOR_STRINGS),
		.N_LEDS_PER_STRING(N_COLOR_LEDS_PER_STRING),
		.FIFO_ADDR_WIDTH(FIFO_ADDR_WIDTH),
		.FIFO_DATA_WIDTH(FIFO_DATA_WIDTH)
	) color_strings (
		.clk(clk_20),
		.reset(reset_20),
		.fifo_full_count(pxl_fifo_full_count),
		.fifo_data(pxl_fifo_data),
		.fifo_data_valid(pxl_fifo_data_valid),
		.fifo_read(pxl_fifo_read),

		.h_blank_in(1'b0),
		.string_active(led[0]),
		.led_sdi(color_led_sdi[N_COLOR_STRINGS-1:0])
	);

	extra_strings #(
		.N_STRINGS(N_WHITE_STRINGS),
		.N_LEDS_PER_STRING(N_WHITE_LEDS_PER_STRING)
	) white_strings (
		.clk(clk_20),
		.reset(reset_20),

		.color_valid(white_value_valid_20),
		.color_in(white_value_in),

		.h_blank_in(1'b0),
		.string_active(led[3]),
		.led_sdi(white_led_sdi)
	);

endmodule
