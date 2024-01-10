/*
 * GPMC is described in https://www.ti.com/lit/ug/spruh73q/spruh73q.pdf
 * section 7.1. This module implements the synchronous mode illustrated
 * in Figure 7-8. The BeagleBoard uses muxed mode address/data.
 */

module gpmc_sync #(
    parameter ADDR_WIDTH = 16,
    parameter DATA_WIDTH = 16
) (
    // GPMC INTERFACE

    // Address[16:1] and Data[15:0]
    inout  [15:0]            gpmc_ad,
    // Address Valid (active low) or Address Latch En (NAND mode)
    input                    gpmc_adv_n,
    // Chip select 1
    input                    gpmc_cs_n,
    // Write En (active low)
    input                    gpmc_we_n,
    // Output En (active low)
    input                    gpmc_oe_n,
    input                    gpmc_clk,

    // HOST INTERFACE
    output                   rd_en,
    output                   wr_en,
    output                   address_valid,
    output [ADDR_WIDTH:0]    address,
    output [DATA_WIDTH-1:0]  data_out,
    input  [DATA_WIDTH-1:0]  data_in
);

reg [ADDR_WIDTH-1:0] addr_lcl;
reg [DATA_WIDTH-1:0] data_out_lcl;

wire [DATA_WIDTH-1:0] gpmc_data_out;
wire [DATA_WIDTH-1:0] gpmc_ad_in;

reg rd_en_lcl = 1'b0;
reg wr_en_lcl = 1'b0;
reg address_valid_lcl;

initial begin
    rd_en_lcl <= 1'b0;
    rd_en_lcl <= 1'b0;
    address_valid_lcl <= 1'b0;
    addr_lcl <= 0;
    data_out_lcl <= 0;
end

assign rd_en = rd_en_lcl;
assign wr_en = wr_en_lcl;
assign address_valid = address_valid_lcl;
// AD contains address [17:1], with the bottom bit represented by the
// byte-enables. We don't use the enables. Add a zero to the end of
// the address just to make calls to devmem match the actual register
// addresses.
assign address = { addr_lcl, 1'b0 };
assign data_out = data_out_lcl;

assign gpmc_data_out = data_in;

//Tri-State buffer control
SB_IO # (
    .PIN_TYPE(6'b1010_01),
    .PULLUP(1'b0)
) gpmc_ad_io [15:0] (
    .PACKAGE_PIN(gpmc_ad),
    .OUTPUT_ENABLE(~gpmc_cs_n && ~gpmc_oe_n),
    .D_OUT_0(gpmc_data_out),
    .D_IN_0(gpmc_ad_in),
    .D_OUT_1(),
    .D_IN_1(),
    .LATCH_INPUT_VALUE(),
    .CLOCK_ENABLE(1'b1),
    .INPUT_CLK(gpmc_clk),
    .OUTPUT_CLK()
);

always @ (negedge gpmc_clk or posedge gpmc_cs_n)
begin
    if (gpmc_cs_n) begin
        // CS deasserted
        address_valid_lcl <= 1'b0;
    end else begin
        // CS asserted
        if (gpmc_adv_n == 1'b0) begin
            // Address phase
            addr_lcl <= gpmc_ad_in;
            address_valid_lcl <= 1'b1;
        end
    end
end

always @ (negedge gpmc_clk)
begin
    // Don't reset read/write enables on CS_n; they persist after the
    // GPMC transaction on the wire.
    rd_en_lcl <= 1'b0;
    wr_en_lcl <= 1'b0;
    if (~gpmc_cs_n && address_valid_lcl && gpmc_adv_n) begin
        // Data phase
        data_out_lcl <= gpmc_ad_in;
        wr_en_lcl <= ~gpmc_we_n;
        rd_en_lcl <= gpmc_we_n && ~gpmc_oe_n;
    end
end

endmodule
