// The simple_fifo component instantiates two FifoCounterHalf components to implement
// the read and write pointers as well as the dual-port RAM (with parity) to implement
// the FIFO storage. The component itself contains no logic, just wiring.
//
// @see work.DpParityRam, work.FifoCounterHalf

// @brief A FIFO with configurable width and depth
module simple_fifo #(
    // The read latency of the FIFO
    parameter bit[1:0] LATENCY = 2,
    // Log base 2 of the FIFO depth
    parameter int ADDR_WIDTH = 13,
    // The width of the data inputs and outputs
    parameter int DATA_WIDTH = 16
) (
    // The write clock. All i* signals are sychronous to iclk
    input wire logic iclk,
    // Resets the write pointer
    input wire logic ireset,
    // Data to write to the FIFO
    input wire logic[DATA_WIDTH-1:0] idata,
    // Write enable
    input wire logic iwr,
    // The number of writes that can occur before the FIFO is full
    output wire logic[ADDR_WIDTH:0] iempty_count,
    // Asserts for one cycle if the FIFO is written while full
    output wire logic ioverflow,

    // The read clock. All o* signals are sychronous to oclk
    input wire logic oclk,
    // Resets the read pointer
    input wire logic oreset,
    // The data read from the FIFO
    output wire logic[DATA_WIDTH-1:0] odata,
    // Qualifies odata
    output wire logic odata_valid,
    // Read enable
    input wire logic ord,
    // The number of valid reads that can occur until the FIFO is empty
    output wire logic[ADDR_WIDTH:0] ofull_count,
    // Asserts for one cycle if the FIFO is read while empty
    output wire logic ounderflow
);

    logic[ADDR_WIDTH:0] iaddr;
    logic[ADDR_WIDTH:0] oaddr;

    fifo_counter_half #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .WR_SIDE(1'b1)
    ) write_counters (
        .near_reset(ireset),
        .near_clk(iclk),
        .nadvance(iwr),
        .ncount(iempty_count),
        .naddr(iaddr),
        .nerr(ioverflow),

        .far_reset(oreset),
        .far_clk(oclk),
        .faddr(oaddr)
    );

    fifo_counter_half #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .WR_SIDE(1'b0)
    ) read_counters (
        .near_reset(oreset),
        .near_clk(oclk),
        .nadvance(ord),
        .ncount(ofull_count),
        .naddr(oaddr),
        .nerr(ounderflow),

        .far_reset(ireset),
        .far_clk(iclk),
        .faddr(iaddr)
    );

    // Actual dual-port RAM addresses do not contain the top bit, which is only used for
    // overflow/underflow detection
    dp_ram #(
        .LATENCY(LATENCY),
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) ram (
        .iclk(iclk),
        .iaddr(iaddr[ADDR_WIDTH-1:0]),
        .iwr(iwr),
        .idata(idata),
        .oclk(oclk),
        .oaddr(oaddr[ADDR_WIDTH-1:0]),
        .ord(ord),
        .odata(odata),
        .odata_valid(odata_valid)
    );

endmodule