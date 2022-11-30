/*
 * Top-level module for cloud ceiling.
 */

module top(
	input clk_100,
	input glbl_reset,

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
	localparam FIFO_ADDR_WIDTH = 12;
	localparam FIFO_DATA_WIDTH = 16;

	wire clk_20;
	wire pll_locked;

	pll system_pll (
		.reset_n(~glbl_reset),
		.clock_in(clk_100),
		.clock_out(clk_20),
		.locked(pll_locked)
	);

	reg reset_ms_100 = 1'b1;
	reg reset_100 = 1'b1;
	always @(posedge clk_100)
	begin
		// Double-sync reset onto clk_100
		reset_ms_100 <= glbl_reset;
		reset_100 <= reset_ms_100;
	end

	reg reset_ms_20 = 1'b1;
	reg reset_20 = 1'b1;
	always @(posedge clk_20)
	begin
		// Double-sync reset onto clk_20
		// Note that this isn't really safe because the combinatorial input to the metastable flop.
		reset_ms_20 <= ~pll_locked || glbl_reset;
		reset_20 <= reset_ms_20;
	end

	reg gpmc_reset_ms = 1'b1;
	reg gpmc_reset = 1'b1;
	always @(posedge gpmc_clk)
	begin
		// Double-sync reset onto gpmc_clk
		gpmc_reset_ms <= glbl_reset;
		gpmc_reset <= gpmc_reset_ms;
	end

	wire gpmc_address_valid;
	wire gpmc_rd_en;
	wire gpmc_wr_en;
	wire [GPMC_ADDR_WIDTH:0] gpmc_address;
	reg  [GPMC_DATA_WIDTH-1:0] gpmc_data_in;
	wire [GPMC_DATA_WIDTH-1:0] gpmc_data_out;

	// Light LED[1] when there's a GPMC transaction
	assign led[1] = ~gpmc_csn1;

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

	reg [15:0] basic_data_out = 0;
	reg [15:0] scratch = 16'h1234;
	reg        addr_valid_q;
	reg [15:0] last_addr = 0;
	reg [15:0] last_addr_q = 0;

	reg gpmc_reset_100_ms, gpmc_reset_100;
	reg gpmc_reset_20_ms, gpmc_reset_20;
	reg gpmc_locked_ms, gpmc_locked;

	always @(posedge gpmc_clk)
	begin : BASIC_REGS
		// Basic info regs
		addr_valid_q <= gpmc_address_valid;
		if (gpmc_address_valid && !addr_valid_q) begin
			last_addr <= gpmc_address;
			last_addr_q <= last_addr;
		end

		gpmc_reset_100_ms <= reset_100;
		gpmc_reset_100 <= gpmc_reset_100_ms;
		gpmc_reset_20_ms <= reset_20;
		gpmc_reset_20 <= gpmc_reset_20_ms;
		gpmc_locked_ms <= pll_locked;
		gpmc_locked <= gpmc_locked_ms;

		// Read registers
		basic_data_out <= 16'h0000;
		if (gpmc_address_valid) begin
			if (gpmc_address == 16'h0) begin
				// ID register
				basic_data_out <= 16'hC10D;
			end else if (gpmc_address == 16'h2) begin
				basic_data_out <= scratch;
			end else if (gpmc_address == 16'h4) begin
				// reset status
				basic_data_out[15:2] <= 0;
				basic_data_out[1:0] <= { gpmc_reset_100, gpmc_reset_20 };
			end
		end

		// Write registers
		if (gpmc_wr_en) begin
			if (gpmc_address == 16'h2) begin
				scratch <= gpmc_data_out;
			end
		end
	end

	reg [15:0] fifo_data_out = 0;
	wire       fifo_overflow;
	reg        fifo_overflow_latched = 0;
	wire       fifo_underflow;
	reg        fifo_underflow_latched = 0;
	reg        fifo_clear_err = 0;
	wire [FIFO_ADDR_WIDTH:0] fifo_empty_count;

	always @(posedge gpmc_clk)
	begin : FIFO_STATUS
		if (fifo_clear_err)
			fifo_overflow_latched <= 1'b0;
			fifo_underflow_latched <= 1'b0;

		if (fifo_overflow)
			fifo_overflow_latched <= 1'b1;
		if (fifo_underflow)
			fifo_underflow_latched <= 1'b1;
	end

	reg gpmc_hblank = 0;

	always @(posedge gpmc_clk)
	begin : FIFO_REGS
		// FIFO status regs

		// Read registers
		fifo_data_out <= 16'h0000;
		if (gpmc_address_valid) begin
			if (gpmc_address == 16'h10) begin
				// Status
				fifo_data_out[15:5] <= 0;
				fifo_data_out[4] <= fifo_overflow_latched;
				fifo_data_out[4:1] <= 0;
				fifo_data_out[0] <= fifo_underflow_latched;
			end else if (gpmc_address == 16'h12) begin
				// Empty count
				fifo_data_out <= fifo_empty_count;
			end
		end

		fifo_clear_err <= 1'b0;
		gpmc_hblank <= 1'b0;
		// Write registers
		if (gpmc_wr_en) begin
			if (gpmc_address == 16'h10) begin
				// Set bit zero to clear FIFO errors
				fifo_clear_err <= gpmc_data_out[0];
			end else if (gpmc_address == 16'h14) begin
				gpmc_hblank <= gpmc_data_out[0];
			end
		end
	end

	// OR together all data outputs
	always @(posedge gpmc_clk) begin
		gpmc_data_in <= basic_data_out | fifo_data_out;
	end

	wire gpmc_fifo_write;
	// Anything in the second page will write to the FIFO
	assign gpmc_fifo_write = (gpmc_wr_en && gpmc_address[15:12] == 4'h1);

	reg fifo_toggle = 1'b0;
	always @(posedge gpmc_clk)
	begin
		if (gpmc_fifo_write)
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
		//.kDataWidth(8),
		//.kAddrWidth(12)
	) pixel_fifo (
		.IClk(gpmc_clk),
		.iReset(gpmc_reset),
		.iData(gpmc_data_out),
		.iWr(gpmc_fifo_write),
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
		.OClk(gpmc_clk),
		.oEvent(fifo_underflow)
	);

	// Bring HBLANK register bit to clk_20
	wire h_blank;
	EventXing hblank_xing (
		.IClk(gpmc_clk),
		.iReady(),
		.iEvent(gpmc_hblank),
		.OClk(clk_20),
		.oEvent(h_blank)
	);

	// String drivers
	parallel_strings #(
		.N_STRINGS(2),
		.N_LEDS_PER_STRING(128),
		.FIFO_ADDR_WIDTH(FIFO_ADDR_WIDTH),
		.FIFO_DATA_WIDTH(FIFO_DATA_WIDTH)
	) all_strings (
		.clk(clk_20),
		.reset(reset_20),
		.fifo_full_count(pxl_fifo_full_count),
		.fifo_data(pxl_fifo_data),
		.fifo_data_valid(pxl_fifo_data_valid),
		.fifo_read(pxl_fifo_read),

		.h_blank_in(h_blank),
		.string_active(led[0]),
		.led_sdi(led_sdi)
	);

endmodule
