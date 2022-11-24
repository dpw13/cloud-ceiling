/*
 * GPMC is described in https://www.ti.com/lit/ug/spruh73q/spruh73q.pdf
 * section 7.1. This module implements the synchronous mode illustrated
 * in Figure 7-8. The BeagleBoard uses muxed mode address/data.
 */

module gpmc_sync (// GPMC INTERFACE

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
                  output [ADDR_WIDTH-1:0]  address,
                  output [DATA_WIDTH-1:0]  data_out,
                  input  [DATA_WIDTH-1:0]  data_in);

parameter ADDR_WIDTH = 16;
parameter DATA_WIDTH = 16;

reg [ADDR_WIDTH-1:0] addr_lcl;
reg [DATA_WIDTH-1:0] data_out_lcl;

wire [DATA_WIDTH-1:0] gpmc_data_out;
wire [DATA_WIDTH-1:0] gpmc_ad_in;

reg rd_en_lcl;
reg wr_en_lcl;
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
assign address = addr_lcl;
assign data_out = data_out_lcl;

assign gpmc_data_out = data_in;

//Tri-State buffer control
SB_IO # (
    .PIN_TYPE(6'b1010_01),
    .PULLUP(1'b0)
) gpmc_ad_io [15:0] (
    .PACKAGE_PIN(gpmc_ad),
    .OUTPUT_ENABLE(!gpmc_cs_n && !gpmc_oe_n),
    .D_OUT_0(gpmc_data_out),
    .D_IN_0(gpmc_ad_in)
);

always @ (negedge gpmc_clk)
begin
    rd_en_lcl <= 1'b0;
    wr_en_lcl <= 1'b0;
    if (gpmc_cs_n) begin
        // CS inactive
        addr_lcl <= 0;
        address_valid_lcl <= 1'b0;
    end else begin
        // CS active
        if (gpmc_adv_n == 1'b0) begin
            // Address phase
            addr_lcl <= gpmc_ad_in;
            address_valid_lcl <= 1'b1;
        end else if (address_valid_lcl) begin
            // Data phase
            wr_en_lcl <= !gpmc_we_n;
            rd_en_lcl <= gpmc_we_n && !gpmc_oe_n;
        end
    end
end

endmodule
