/*
 * GPMC is described in https://www.ti.com/lit/ug/spruh73q/spruh73q.pdf
 * section 7.1. This module implements the synchronous mode illustrated
 * in Figure 7-8. The BeagleBoard uses muxed mode address/data.
 */

module gpmc_sync #(
    parameter ADDR_WIDTH = 16,
    parameter DATA_WIDTH = 16
) (
    // HOST INTERFACE
    cpu_if.cpu cpuif,

    // GPMC INTERFACE

    // Address[16:1] and Data[15:0]
    inout wire [15:0] gpmc_ad,
    // Address Valid (active low) or Address Latch En (NAND mode)
    input wire        gpmc_adv_n,
    // Chip select 1
    input wire        gpmc_cs_n,
    // Write En (active low)
    input wire        gpmc_we_n,
    // Output En (active low)
    input wire        gpmc_oe_n,
    input wire        gpmc_clk
);

logic [ADDR_WIDTH-1:0] addr_lcl = '0;
logic [DATA_WIDTH-1:0] data_out_lcl = '0;

wire [DATA_WIDTH-1:0] gpmc_data_out;
wire [DATA_WIDTH-1:0] gpmc_ad_in;

logic rd_en_lcl = 1'b0;
logic wr_en_lcl = 1'b0;
logic address_valid_lcl = 1'b0;

assign cpuif.req = rd_en_lcl | wr_en_lcl;
assign cpuif.req_is_wr = wr_en_lcl;
// AD contains address [17:1], with the bottom bit represented by the
// byte-enables. We don't use the enables. Add a zero to the end of
// the address just to make calls to devmem match the actual register
// addresses.
assign cpuif.addr = { addr_lcl, 1'b0 };
assign cpuif.wr_data = data_out_lcl;
assign cpuif.wr_biten = '1;

assign gpmc_data_out = cpuif.rd_data;

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
