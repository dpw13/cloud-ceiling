// Does what it says on the tin. Note there is no reset on this module
// to ensure we correctly map to memories lacking resets.

// @brief A true dual-port RAM with one read port and one write port of the same width
module dp_ram #(
    // The width of the address pointers
    parameter int ADDR_WIDTH = 10,
    // The width of the RAM data
    parameter int DATA_WIDTH = 32
) (
    // The write clock. All i* signals are synchronous to iclk
    input wire logic iclk,
    // The write pointer
    input wire logic[ADDR_WIDTH-1:0] iaddr,
    // Write enable
    input wire logic iwr,
    // Data to be written
    input wire logic[DATA_WIDTH-1:0] idata,

    // The read clock. All o* signals are synchronous to oclk
    input wire logic oclk,
    // The read pointer
    input wire logic[ADDR_WIDTH-1:0] oaddr,
    // Read enable
    input wire logic ord,
    // The data read
    output wire logic[DATA_WIDTH-1:0] odata,
    // Qualifier for odata: asserts LATENCY cycles after ord
    output wire logic odata_valid
);

    logic[ADDR_WIDTH-1:0] oaddr_q;
    logic[DATA_WIDTH-1:0] RAM[2**ADDR_WIDTH-1:0]; 
    logic[DATA_WIDTH-1:0] odata_q;
    logic ord_q, ord_qq = 1'b0;

    initial RAM[0] <= 0;

    always_ff @(posedge iclk) begin : wr_proc
        if (iwr)
            RAM[iaddr] <= idata;
    end

    always_ff @(posedge oclk) begin : rd_proc
        oaddr_q <= oaddr;
        // Reads occur constantly. There are some power savings to be had by powering down
        // the read side of RAMs, but I haven't implemented that here. The DataValid output
        // is provided for convenience for indicating the latency of the RAM.
        ord_q <= ord;
        ord_qq <= ord_q;
        // yosys is not very smart about inferring RAMs. This output needs to be registered
        // with a very simple statement.
        odata_q <= RAM[oaddr_q];
    end

    assign odata = odata_q;
    assign odata_valid = ord_qq;

endmodule