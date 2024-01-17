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
logic [DATA_WIDTH-1:0] data_in_lcl = '0;
wire [DATA_WIDTH-1:0] gpmc_ad_in;

logic rd_en_tgl = 1'b0;
logic wr_en_tgl = 1'b0;
logic address_valid_tgl = 1'b0;

//Tri-State buffer control
SB_IO # (
    .PIN_TYPE(6'b1010_01),
    .PULLUP(1'b0)
) gpmc_ad_io [15:0] (
    .PACKAGE_PIN(gpmc_ad),
    .OUTPUT_ENABLE(~gpmc_cs_n && ~gpmc_oe_n),
    .D_OUT_0(data_in_lcl),
    .D_IN_0(gpmc_ad_in),
    .D_OUT_1(),
    .D_IN_1(),
    .LATCH_INPUT_VALUE(),
    .CLOCK_ENABLE(1'b1),
    .INPUT_CLK(gpmc_clk),
    .OUTPUT_CLK()
);

always_ff @ (posedge gpmc_clk)
begin
    if (~gpmc_cs_n) begin
        // CS asserted
        if (gpmc_adv_n == 1'b0) begin
            // Address phase
            addr_lcl <= gpmc_ad_in;
            address_valid_tgl <= ~address_valid_tgl;

            // AAD mode would assert gpmc_oe_n but we don't support that
            // at the moment (there are no addresses above 16 bits of addr)
        end else begin
            if (~gpmc_we_n) begin
                // Write
                data_out_lcl <= gpmc_ad_in;
                wr_en_tgl <= ~wr_en_tgl;
            end

            if (~gpmc_oe_n) begin
                // Read
                rd_en_tgl <= ~rd_en_tgl;
            end
        end
    end
end

logic addr_valid_ms, addr_valid_cpu, addr_valid_cpu_q;
logic rd_en_ms, rd_en_cpu, rd_en_cpu_q;
logic wr_en_ms, wr_en_cpu, wr_en_cpu_q;

logic [ADDR_WIDTH-1:0] addr_cpu = '0;
logic [DATA_WIDTH-1:0] wr_data = '0;
logic req, req_is_wr;

always_ff @(posedge cpuif.clk) begin
    if (cpuif.reset) begin
        addr_valid_ms <= 1'b0;
        addr_valid_cpu <= 1'b0;
        addr_valid_cpu_q <= 1'b0;

        rd_en_ms <= 1'b0;
        rd_en_cpu <= 1'b0;
        rd_en_cpu_q <= 1'b0;

        wr_en_ms <= 1'b0;
        wr_en_cpu <= 1'b0;
        wr_en_cpu_q <= 1'b0;

        req <= 1'b0;
        req_is_wr <= 1'b0;
        addr_cpu <= '0;
        wr_data <= '0;
        data_in_lcl <= '0;
    end else begin
        // Strobes
        req <= 1'b0;
        req_is_wr <= 1'b0;

        addr_valid_ms <= address_valid_tgl;
        addr_valid_cpu <= addr_valid_ms;
        addr_valid_cpu_q <= addr_valid_cpu;

        // AD contains address [17:1], with the bottom bit represented by the
        // byte-enables. We don't use the enables. Add a zero to the end of
        // the address just to make calls to devmem match the actual register
        // addresses.
        if (addr_valid_cpu != addr_valid_cpu_q) begin
            addr_cpu <= { addr_lcl, 1'b0 };
            // Clear the input data for clarity
            data_in_lcl <= '0;
        end

        rd_en_ms <= rd_en_tgl;
        rd_en_cpu <= rd_en_ms;
        rd_en_cpu_q <= rd_en_cpu;
        if (rd_en_cpu != rd_en_cpu_q) begin
            req <= 1'b1;
            req_is_wr <= 1'b0;
        end

        wr_en_ms <= wr_en_tgl;
        wr_en_cpu <= wr_en_ms;
        wr_en_cpu_q <= wr_en_cpu;
        if (wr_en_cpu != wr_en_cpu_q) begin
            req <= 1'b1;
            req_is_wr <= 1'b1;
            wr_data <= data_out_lcl;
        end

        // No ACK timing is supported since no backpressure is possible. In the
        // future it's probably worth at least recording any protocol errors in
        // counters.
        if (cpuif.rd_ack)
            data_in_lcl <= cpuif.rd_data;
    end
end

assign cpuif.addr = addr_cpu;
assign cpuif.req = req;
assign cpuif.req_is_wr = req_is_wr;
assign cpuif.wr_data = wr_data;
assign cpuif.wr_biten = '1; // byte enables ignored for now

endmodule
