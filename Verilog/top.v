module top(
	input clk_100,
	input reset_n,

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
	localparam FIFO_ADDR_WIDTH = 12;
	localparam FIFO_DATA_WIDTH = 16;

	wire clk_20;
	wire pll_locked;

	pll system_pll (
		.reset_n(reset_n),
		.clock_in(clk_100),
		.clock_out(clk_20),
		.locked(pll_locked)
	);

	reg reset_ms_100 = 1'b1;
	reg reset_100 = 1'b1;
	always @(posedge clk_100)
	begin
		// Double-sync reset onto clk_100
		reset_ms_100 <= !reset_n;
		reset_100 <= reset_ms_100;
	end

	reg reset_ms_20 = 1'b1;
	reg reset_20 = 1'b1;
	always @(posedge clk_20)
	begin
		// Double-sync reset onto clk_20
		// Note that this isn't really safe because the combinatorial input to the metastable flop.
		reset_ms_20 <= ~pll_locked || !reset_n;
		reset_20 <= reset_ms_20;
	end

	reg gpmc_reset_ms = 1'b1;
	reg gpmc_reset = 1'b1;
	always @(posedge gpmc_clk)
	begin
		// Double-sync reset onto gpmc_clk
		gpmc_reset_ms <= !reset_n;
		gpmc_reset <= gpmc_reset_ms;
	end

	wire gpmc_address_valid;
	wire gpmc_rd_en;
	wire gpmc_wr_en;
	wire [GPMC_ADDR_WIDTH-1:0] gpmc_address;
	reg  [GPMC_DATA_WIDTH-1:0] gpmc_data_in;
	wire [GPMC_DATA_WIDTH-1:0] gpmc_data_out;

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

	reg [15:0] basic_data_out = 16'h1234;
	reg [15:0] scratch = 16'h1234;

	always @(posedge gpmc_clk)
	begin
		// Basic info regs

		// Read registers
		basic_data_out <= 16'h0000;
		if (gpmc_address_valid) begin
			if (gpmc_address == 16'h0) begin
				// ID register
				basic_data_out <= 16'hC10D;
			end else if (gpmc_address == 16'h2) begin
				basic_data_out <= scratch;
			end
		end

		// Write registers
		if (gpmc_wr_en) begin
			if (gpmc_address == 16'h2) begin
				scratch <= gpmc_data_out;
			end
		end
	end

	// OR together all data outputs
	always @(posedge gpmc_clk) begin
		gpmc_data_in <= basic_data_out;
	end

	wire gpmc_fifo_write;
	assign gpmc_fifo_write = (gpmc_wr_en && gpmc_address == 16'h4000);

	reg         pxl_fifo_read = 1'b0;
	wire [FIFO_ADDR_WIDTH:0]   pxl_fifo_full_count; // Full count is one bit wider than kAddrWidth
	wire [FIFO_DATA_WIDTH-1:0] pxl_fifo_data;
	wire        pxl_fifo_data_valid;
	wire [23:0] pxl_data;

	assign pxl_data = { pxl_fifo_data[7:0], pxl_fifo_data};

	SimpleFifo # (
		//.kLatency(2),
		//.kDataWidth(8),
		//.kAddrWidth(12)
	) pixel_fifo (
		.IClk(gpmc_clk),
		.iReset(gpmc_reset),
		.iData(gpmc_data_out),
		.iWr(gpmc_fifo_write),
		.iEmptyCount(),
		.iOverflow(),

		.OClk(clk_20),
		.oReset(reset_20),
		.oData(pxl_fifo_data),
		.oDataValid(pxl_fifo_data_valid),
		.oDataErr(),
		.oRd(pxl_fifo_read),
		.oFullCount(pxl_fifo_full_count),
		.oUnderflow()
	);

	wire pxl_string_ready;

	// TODO: The ready signal above isn't responsive enough. We end up popping multiple elements off
	// the FIFO before the first word is shifted out.
	always @(posedge clk_20)
	begin
		if (reset_20) begin
			pxl_fifo_read <= 1'b0;
		end else begin
			// Don't assert read twice in a row
			pxl_fifo_read <= pxl_fifo_full_count > 0 && pxl_string_ready && !pxl_fifo_read;
		end
	end

	string_driver #(
		.CLK_PERIOD_NS(50)
	) string_driverx (
		.clk(clk_20),
		.pixel_data(pxl_data),
		.pixel_fifo_rd(pxl_fifo_read),
		.pixel_data_valid(pxl_fifo_data_valid),
		.h_blank(1'b0),
		.sdi(led_sdi[0]),
		.string_ready(pxl_string_ready)
	);

	assign led_sdi[1] = 0;
endmodule
