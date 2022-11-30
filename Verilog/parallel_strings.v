/*
 * Wrapper for multiple string_drivers. This module pops from the
 * pixel FIFO, shifts 16 bit words into 24-bit color tuples, and
 * queues the data for parallel string drivers.
 */

module parallel_strings #(
    parameter N_STRINGS = 4,
    parameter N_LEDS_PER_STRING = 150,
    parameter FIFO_ADDR_WIDTH = 12,
    parameter FIFO_DATA_WIDTH = 16
) (
    input clk,
    input reset,

    input [FIFO_ADDR_WIDTH:0]   fifo_full_count,
    input [FIFO_DATA_WIDTH-1:0] fifo_data,
    input                       fifo_data_valid,
    output                      fifo_read,

    input  h_blank_in,
    output string_active,

    output [N_STRINGS-1:0] led_sdi
);

    localparam TOTAL_PIXELS = N_STRINGS*N_LEDS_PER_STRING;
    localparam TOTAL_PIXEL_BYTES = TOTAL_PIXELS * 3; // 3 bytes of color data per pixel
    localparam FIFO_DATA_BYTES = FIFO_DATA_WIDTH / 8;
    // This is the total number of words in the FIFO we need before shifting out all data.
    localparam TOTAL_PIXEL_FIFO_WORDS = TOTAL_PIXEL_BYTES/FIFO_DATA_BYTES;
    localparam BYTES_PER_COL = N_STRINGS * 3;
    localparam FIFO_WORDS_PER_COL = BYTES_PER_COL/FIFO_DATA_BYTES;

    localparam FLUSH_TICKS = 6;

    wire [N_STRINGS-1:0] string_ready;
    reg [N_STRINGS-1:0] pxl_data_valid = 0;

    reg fifo_read_lcl = 1'b0;
    assign fifo_read = fifo_read_lcl;

    reg frame_active = 1'b0;
    reg [$clog2(N_STRINGS)-1:0] active_string = 0;
    reg [$clog2(FLUSH_TICKS)-1:0] flush_timer = 0;
    reg [$clog2(N_LEDS_PER_STRING)-1:0] pixels_remaining = 0;
    reg [$clog2(FIFO_WORDS_PER_COL+1)-1:0] words_remaining = 0;

    reg h_blank = 1'b0;

    always @(posedge clk)
    begin
        if (reset) begin
            frame_active <= 1'b0;
            pixels_remaining <= 0;
            words_remaining <= 0;
            h_blank <= 1'b0;
            flush_timer <= 0;
        end else begin
            h_blank <= 1'b0;
            // Only start shifting once we have enough data to write the entire string.
            // Otherwise only a few LEDs will light.
            // We need to be careful we don't shift out more than the expected amount
            // of LED data at once. If software writes e.g. 1.5 frames, we should shift
            // out the first frame and then stop until we have another full frame.
            if (fifo_full_count >= TOTAL_PIXEL_FIFO_WORDS && ~frame_active && ~string_active) begin
                frame_active <= 1'b1;
                h_blank <= 1'b1;
                pixels_remaining <= N_LEDS_PER_STRING - 1;
                // First row requires an extra read to prime the shift register
                words_remaining <= FIFO_WORDS_PER_COL;
            end

            if (flush_timer > 0) begin
                flush_timer <= flush_timer - 1;
                if (flush_timer == 1) begin
                    frame_active <= 1'b0;
                end
            end

            if (fifo_read_lcl) begin
                if (pixels_remaining == 0 && words_remaining == 1) begin
                    // This is the last FIFO access for the last pixel
                    flush_timer <= FLUSH_TICKS - 1;
                end

                if (words_remaining != 0) begin
                    // Still completing a column
                    words_remaining <= words_remaining - 1;
                end else begin
                    // Completed this pixel for all strings
                    if (pixels_remaining != 0) begin
                        pixels_remaining <= pixels_remaining - 1;
                        words_remaining <= FIFO_WORDS_PER_COL - 1;
                    end
                end
            end
        end
    end


    // The ready signal above isn't responsive enough. We end up popping multiple elements off
    // the FIFO before the first word is shifted out, so we need to avoid reading twice in quick
    // succession. That's ok though because the LED shifter is extremely slow.
    //
    // This is made easier by the fact that we round-robin through all the string drivers. This
    // design won't work as-is if only a single driver is used.
    reg flush_shift_reg = 1'b0;
    always @(posedge clk)
    begin
        if (reset || ~frame_active) begin
            fifo_read_lcl <= 1'b0;
            flush_shift_reg <= 1'b0;
        end else begin
            // Don't assert read twice in a row
            if (flush_timer > 0) begin
                flush_shift_reg <= (flush_timer == 3);
                fifo_read_lcl <= 1'b0;
            end else begin
                flush_shift_reg <= 1'b0;
                fifo_read_lcl <= fifo_full_count > 0 && string_ready[active_string] && !fifo_read_lcl;
            end
        end
    end

    reg [47:0] fifo_shift_reg = 0;
    reg [1:0] fifo_shift_count = 0;
    reg fifo_shift_reg_primed = 0;
    always @(posedge clk)
    begin
        if (reset || ~frame_active) begin
            fifo_shift_reg <= 0;
            fifo_shift_count <= 0;
            pxl_data_valid <= 1'b0;
            fifo_shift_reg_primed <= 1'b0;
            active_string <= 0;
        end else begin
            pxl_data_valid <= 1'b0;

            if (fifo_data_valid || flush_shift_reg) begin
                // Write data to top of shift register and shift down
                fifo_shift_reg <= { fifo_data, fifo_shift_reg[47:16] };

                // Keep track of how many words we've shifted in. This will determine which
                // bits are valid in the shift register.
                if (fifo_shift_count == 2) begin
                    fifo_shift_count <= 1'b0;
                    fifo_shift_reg_primed <= 1'b1;
                end else begin
                    fifo_shift_count <= fifo_shift_count + 1;
                end

                // Pixel data is valid after shift count 1 and 2
                if (fifo_shift_count == 2 || (fifo_shift_count == 0 && fifo_shift_reg_primed)) begin
                    pxl_data_valid[active_string] <= 1'b1;
                    if (active_string == (N_STRINGS - 1)) begin
                        active_string <= 0;
                    end else begin
                        active_string <= active_string + 1;
                    end
                end
            end
        end
    end

    wire [23:0] pxl_data;
    assign pxl_data = (fifo_shift_count == 0) ? fifo_shift_reg[23:0] : fifo_shift_reg[31:8];

    genvar string;
    generate
        for (string = 0; string < N_STRINGS; string = string + 1) begin
            string_driver #(
                .CLK_PERIOD_NS(50)
            ) string_driverx (
                .clk(clk),
                .pixel_data(pxl_data),
                .pixel_data_valid(pxl_data_valid[string]),
                .h_blank(h_blank),
                .sdi(led_sdi[string]),
                .string_ready(string_ready[string])
            );
        end
    endgenerate

    // Assert string_active if any string is busy
	assign string_active = ~(&string_ready);

endmodule