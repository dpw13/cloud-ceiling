// The fifo_counter_half component implements one of the two address pointers needed
// to implement a FIFO: either the read half or the write half. It advances cAddr
// every cycle that cAdvance is asserted and calculates the difference between the
// local and remote pointer (resulting in the full or empty count) and exposes the
// value in cCount. It moves the remote address across clock domains using a
// VectorXing.
//
// The component implements one additional bit in the address vector than is strictly
// necessary; the top bit is not used to index the FIFO RAM. That bit allows us to
// detect error conditions (either over- or under-flows). If the bottom bits match
// and the top bit matches, that is indicates that the FIFO is empty. This is the
// initial state of the FIFO because both pointers are initialized to zero. If the
// bottom bits match but the top bit does not, that indicates that the FIFO is full.
// This allows us to use all locations in the RAM.
//
// @see work.VectorXing

// @brief Implements the accounting for the read and write FIFO pointers
module fifo_counter_half #(
    // The width of the physical RAM address pointer
    parameter int ADDR_WIDTH = 16,
    // True if this side implements the write pointer, false otherwise
    parameter bit WR_SIDE = 1'b0
) (
    // The local reset
    input wire logic near_reset,
    // The local clock. All c* signals are synchronous to near_clk
    input wire logic near_clk,
    // Advances the FIFO pointer by one each cycle this signal asserts
    input wire logic nadvance,
    // The empty or full count of the FIFO
    output var logic[ADDR_WIDTH:0] ncount,
    // The full-width FIFO pointer
    output var logic[ADDR_WIDTH:0] naddr,
    // Overflow or underflow
    output var logic nerr,

    // The remote reset
    input wire logic far_reset,
    // The remote clock. All r* signals are synchronous to far_clk
    input wire logic far_clk,
    // The remote side's FIFO pointer
    input wire logic[ADDR_WIDTH:0] faddr
);

    logic[ADDR_WIDTH:0] nrem_addr;
    logic[ADDR_WIDTH:0] nrem_addr_raw;

    logic fready;

    localparam logic[ADDR_WIDTH:0] REM_ADDR_ADJ = WR_SIDE ? 2**(ADDR_WIDTH) : 0;

    vector_xing #(
        .DATA_WIDTH(ADDR_WIDTH+1)
    ) addr_xing (
        .ireset(far_reset),
        .iclk(far_clk),
        .idata(faddr),
        .iready(fready),
        .ipush(fready),

        .oreset(near_reset),
        .oclk(near_clk),
        .odata(nrem_addr_raw),
        .odata_valid()
    );

    // On the write side the read pointer is effectively halfway through the
    // address space when both pointers are reset to zero. We define that state
    // as the FIFO being empty, so the empty count should be 2**ADDR_WIDTH, not
    // zero. This is implemented by inverting the top bit of the read address when
    // computing the empty count.

    // On the read side, having both pointers at zero indicates that the full
    // count is zero, so the remote address is unmodified.
    assign nrem_addr = nrem_addr_raw ^ REM_ADDR_ADJ;

    // Implement the accounting for this side of the FIFO
    always_ff @(posedge near_clk) begin : fifo_ctrl
        if (near_reset) begin
            naddr <= '0;
            ncount <= '0;
        end else begin
            automatic logic [ADDR_WIDTH-1:0] naddr_nx = naddr;

            if (nadvance)
                naddr_nx++;
            
            naddr <= naddr_nx;
            // Count should update the next cycle if nadvance asserts
            ncount <= nrem_addr - naddr_nx;
        end
    end

    always_ff @(posedge near_clk) begin : err_detect
        if (near_reset) begin
            nerr <= 1'b0;
        end else begin
            // Detect under- and over-flows when we attempt to advance when no
            // data or space is available. Note that this only detects the first
            // error, not subsequent errors. To do that we could detect advances
            // if the count was greater than the total FIFO capacity, but I've
            // opted to omit that since the first error is sufficient to corrupt
            // data.
            nerr <= nadvance && (ncount == 0);
        end
    end

endmodule