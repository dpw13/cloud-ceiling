/*
 * Top-level module for cloud ceiling.
 */

module top(
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

	localparam GPMC_ADDR_WIDTH = 16;
	localparam GPMC_DATA_WIDTH = 16;
	localparam FIFO_ADDR_WIDTH = 13;
	localparam FIFO_DATA_WIDTH = 16;

	// Testbench params
	//localparam N_COLOR_STRINGS = 5;
	//localparam N_WHITE_STRINGS = 2;
	//localparam N_COLOR_LEDS_PER_STRING = 24;
	//localparam N_WHITE_LEDS_PER_STRING = 24;

	// Production params
	localparam N_COLOR_STRINGS = 23;
	localparam N_WHITE_STRINGS = 4;
	localparam N_COLOR_LEDS_PER_STRING = 236;
	localparam N_WHITE_LEDS_PER_STRING = 118;

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

	wire gpmc_address_valid;
	wire gpmc_rd_en;
	wire gpmc_wr_en;
	wire [GPMC_ADDR_WIDTH:0] gpmc_address;
	logic  [GPMC_DATA_WIDTH-1:0] gpmc_data_in;
	wire [GPMC_DATA_WIDTH-1:0] gpmc_data_out;

	// Light LED[1] when there's a GPMC transaction
	assign led[1] = ~gpmc_csn1;

	cpu_if#(
		.ADDR_WIDTH(GPMC_ADDR_WIDTH),
		.DATA_WIDTH(GPMC_DATA_WIDTH)
	) cpuif(.reset(reset_100), .clk(clk_100));

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
		.cpuif(cpuif.cpu)
	);

    wire cloud_ceiling_regmap__in_t hwif_in;
    wire cloud_ceiling_regmap__out_t hwif_out;

	cloud_ceiling_regmap_wrapper regs (
		.cpuif(cpuif.dev),

		.hwi(hwif_in),
		.hwo(hwif_out)
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

	generate begin: gen_acks
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
	end endgenerate

	logic color_valid;
	logic [23:0] color_in; // Cold Red Warm

	assign color_in = hwif_out.REGS.WHITE_COLOR_REG.VALUE.value;
	assign color_valid = hwif_out.REGS.WHITE_COLOR_REG.VALUE.swmod;

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

	SimpleFifo # (
		//.kLatency(2),
		//.kDataWidth(16),
		//.kAddrWidth(13)
	) pixel_fifo (
		.IClk(clk_100),
		.iReset(reset_100),
		.iData(color_fifo_write_data),
		.iWr(color_fifo_write),
		.iEmptyCount(fifo_empty_count),
		.iOverflow(fifo_overflow),

		.OClk(clk_20),
		.oReset(reset_20),
		.oData(pxl_fifo_data),
		.oDataValid(pxl_fifo_data_valid),
		.oDataErr(),
		.oRd(pxl_fifo_read),
		.oFullCount(pxl_fifo_full_count),
		.oUnderflow(pxl_fifo_underflow)
	);

	// Bring the underflow status back to the GPMC clock domain
	EventXing underflow_xing (
		.IClk(clk_20),
		.iReady(),
		.iEvent(pxl_fifo_underflow),
		.OClk(clk_100),
		.oEvent(fifo_underflow)
	);

	// Bring color_valid bit to clk_20
	wire color_valid_20;
	EventXing color_valid_xing (
		.IClk(clk_100),
		.iReady(),
		.iEvent(color_valid),
		.OClk(clk_20),
		.oEvent(color_valid_20)
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

		.color_valid(color_valid_20),
		.color_in(color_in),

		.h_blank_in(1'b0),
		.string_active(led[3]),
		.led_sdi(white_led_sdi)
	);

endmodule
