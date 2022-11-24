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
);

	localparam GPMC_ADDR_WIDTH = 16;
	localparam GPMC_DATA_WIDTH = 16;
	localparam COUNTER_WIDTH = 28;

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
		.gpmc_ad(gpmc_ad),
		.gpmc_adv_n(gpmc_advn),
		.gpmc_cs_n(gpmc_csn1),
		.gpmc_we_n(gpmc_wein),
		.gpmc_oe_n(gpmc_oen),
		.gpmc_clk(gpmc_clk),

		// HOST INTERFACE
		.rd_en(gpmc_rd_en),
		.wr_en(gpmc_wr_en),
		.address_valid(gpmc_address_valid),
		.address(gpmc_address),
		.data_out(gpmc_data_out),
		.data_in(gpmc_data_in)
	);

	assign gpmc_data_in = 0;

endmodule
