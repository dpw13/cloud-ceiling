module top(
	input clk_100,
	output [3:0] led,

	// GPMC INTERFACE
	inout  [15:0] gpmc_ad,
	input         gpmc_advn,
	input         gpmc_csn1,
	input         gpmc_wein,
	input         gpmc_oen,
	input         gpmc_clk,

	// LED string interface
	output [1:0]  led_sdi
);

	localparam GPMC_ADDR_WIDTH = 16;
	localparam GPMC_DATA_WIDTH = 16;
	localparam COUNTER_WIDTH = 28;
	localparam FIFO_ADDR_WIDTH = 16;

	wire clk_20;
	wire pll_locked;

	pll system_pll (
		.clock_in(clk_100),
		.clock_out(clk_20),
		.locked(pll_locked)
	);


	reg [27:0] counter = 0;
	always @(posedge clk_100)
	begin
		if (gpmc_wr_en && gpmc_address == 0) begin
			counter[GPMC_DATA_WIDTH-1:0] <= gpmc_data_out;
			counter[COUNTER_WIDTH-1:0] <= 0;
		end else begin
			counter <= counter + 1;
		end
	end

	assign led[3:0] = counter[COUNTER_WIDTH-1:COUNTER_WIDTH-4];

	wire gpmc_address_valid;
	wire gpmc_rd_en;
	wire gpmc_wr_en;
	wire [GPMC_ADDR_WIDTH-1:0] gpmc_address;
	wire [GPMC_DATA_WIDTH-1:0] gpmc_data_in;
	wire [GPMC_DATA_WIDTH-1:0] gpmc_data_out;

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
		.rd_en(gpmc_rd_en),
		.wr_en(gpmc_wr_en),
		.address_valid(gpmc_address_valid),
		.address(gpmc_address),
		.data_out(gpmc_data_out),
		.data_in(gpmc_data_in)
	);

	assign gpmc_data_in = 0;

	reg gpmc_fifo_reset = 1'b1;
	reg gpmc_fifo_write = 1'b0;

	always @(posedge gpmc_clk)
	begin
		gpmc_fifo_reset <= 1'b0;
		gpmc_fifo_write <= 1'b0;

		if (gpmc_wr_en && gpmc_address == 0) begin
			gpmc_fifo_write <= 1'b1;
		end
	end

	wire        pxl_fifo_read;
	wire [FIFO_ADDR_WIDTH:0] pxl_fifo_full_count; // Full count is one bit wider than kAddrWidth
	wire  [7:0] pxl_fifo_data;
	wire        pxl_fifo_data_valid;
	wire [23:0] pxl_data;

	assign pxl_data = pxl_fifo_data & pxl_fifo_data & pxl_fifo_data;

	/*
	 * Current problems:
	 *
	 * 1. GHDL synthesizes the top level it knows about, in this case SimpleFifo. That apparently
	 *    means that generics get optimized away, so to change the parameters here we have to update
	 *    the defaults in the VHDL.
	 *
	 * 2. GHDL or yosys aren't preserving the RAM, so there's no underlying storage in the final
	 *    bitfile...
	 */
	SimpleFifo # (
		//.kLatency(2),
		//.kDataWidth(8),
		//.kAddrWidth(12)
	) pixel_fifo (
		.IClk(gpmc_clk),
		.iReset(gpmc_fifo_reset),
		.iData(gpmc_data_out),
		.iWr(gpmc_fifo_write),
		// .iEmptyCount(),
		// .iOverflow(),

		.OClk(clk_20),
		.oReset(1'b0),
		.oData(pxl_data),
		.oDataValid(pxl_fifo_data_valid),
		// .oDataErr()
		.oRd(pxl_fifo_read),
		.oFullCount(pxl_fifo_full_count)
		// .oUnderflow()
	);

	wire pxl_string_ready;
	assign pxl_fifo_read = pxl_fifo_full_count > 0 && pxl_string_ready;

	string_driver #(
		.CLK_PERIOD_NS(50)
	) string_driverx (
		.clk(clk_20),
		.pixel_data(pxl_fifo_data),
		.pixel_data_valid(pxl_fifo_data_valid),
		.h_blank(gpmc_rd_en),
		.sdi(led_sdi[0]),
		.string_ready(pxl_string_ready)
	);

	assign led_sdi[1] = 0;
endmodule
