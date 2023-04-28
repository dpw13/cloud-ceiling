/*
 * Wrapper for multiple string_drivers. This module pops from the
 * pixel FIFO, shifts 16 bit words into 24-bit color tuples, and
 * queues the data for parallel string drivers.
 */

module parallel_strings #(
    parameter N_STRINGS = 4,
    parameter N_LEDS_PER_STRING = 150,
    parameter FIFO_ADDR_WIDTH = 12,
    parameter FIFO_DATA_WIDTH = 16,
    parameter INIT_COLOR = 24'h0C1006 // GGRRBB
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

    localparam FLUSH_TICKS = 6;

    wire [N_STRINGS-1:0] string_ready;

    reg fifo_read_lcl = 1'b0;
    assign fifo_read = fifo_read_lcl;

    reg frame_active = 1'b0;
    reg [$clog2(N_STRINGS)-1:0] active_string = 0;
    reg [$clog2(FLUSH_TICKS)-1:0] flush_timer = 0;
    reg [$clog2(N_LEDS_PER_STRING)-1:0] pixels_remaining = 0;
    reg [$clog2(BYTES_PER_COL+FIFO_DATA_BYTES)-1:0] bytes_remaining = 0;

    reg h_blank = 1'b0;

    // The flush_shift_reg signal is used to flush the additional data in the shift
    // register. The shift register is 48 bits wide, so we still have a full pixel's
    // worth of data left at the end without an additional read.
    reg flush_shift_reg = 1'b0;

    always @(posedge clk)
    begin
        if (reset) begin
            frame_active <= 1'b0;
            pixels_remaining <= 0;
            bytes_remaining <= 0;
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
                // If the number of strings is odd, we can end up with extra data. In theory
                // this would be bytes_remaining of -1. Instead of wasting a bit making this
                // a signed value, let's track the number of bytes remaining + 1. If we have
                // all the data and there's none left over, this value should end up at 1
                // instead of zero.
                bytes_remaining <= BYTES_PER_COL + FIFO_DATA_BYTES + 1;
            end

            if (flush_timer > 0) begin
                flush_timer <= flush_timer - 1;
                if (flush_timer == 1) begin
                    frame_active <= 1'b0;
                end
            end

            if (fifo_read_lcl || flush_shift_reg) begin
                // We are looking for the last real data read. The number of bytes
                // remaining on that cycle will be 3 bytes for the last pixel *plus*
                // the 2 bytes from the remaining read.
                if (pixels_remaining == 0 && bytes_remaining == 5) begin
                    // This is the last FIFO access for the last pixel
                    flush_timer <= FLUSH_TICKS - 1;
                end

                if (bytes_remaining > 3) begin
                    // Still completing a column
                    bytes_remaining <= bytes_remaining - FIFO_DATA_BYTES;
                end else begin
                    // Completed this pixel for all strings
                    if (pixels_remaining != 0) begin
                        pixels_remaining <= pixels_remaining - 1;
                        // We only add the number of bytes in each column. The initial
                        // offset of 1 is added at the beginning of the frame. We're both
                        // subtracting 2 for the active FIFO read and adding the expected
                        // number of bytes for the next column.
                        bytes_remaining <= bytes_remaining + BYTES_PER_COL - FIFO_DATA_BYTES;
                    end
                end
            end
        end
    end

    // h_blank timing is affected by the advancement of the ready signal in
    // string_driver. If we assert h_blank too quickly after ready, we'll miss it.
    reg h_blank_q = 1'b0;
    always @(posedge clk)
    begin
        if (reset) begin
            h_blank_q <= 1'b0;
        end else begin
            h_blank_q <= h_blank;
        end
    end

    // The ready signal above isn't responsive enough. We end up popping multiple elements off
    // the FIFO before the first word is shifted out, so we need to avoid reading twice in quick
    // succession. That's ok though because the LED shifter is extremely slow.
    //
    // This is made easier by the fact that we round-robin through all the string drivers. This
    // design won't work as-is if only a single driver is used.
    reg [1:0] fifo_shift_count = 0;
    reg fifo_shift_reg_primed = 0;
    reg must_wait_for_ready = 1'b0;
    reg next_word_completes_pixel = 1'b0;

    always @(posedge clk)
    begin
        if (reset || ~frame_active) begin
            fifo_read_lcl <= 1'b0;
            flush_shift_reg <= 1'b0;
            fifo_shift_count <= 0;
            fifo_shift_reg_primed <= 1'b0;
            active_string <= 0;
            must_wait_for_ready <= 1'b0;
            next_word_completes_pixel <= 1'b0;
        end else begin
            if (flush_timer > 0 && flush_timer < 8) begin
                fifo_read_lcl <= 1'b0;
                flush_shift_reg <= (flush_timer == 3);
                fifo_shift_count <= 0;
                fifo_shift_reg_primed <= 1'b0;
            end else begin
                fifo_read_lcl <= 1'b0;
                flush_shift_reg <= 1'b0;

                // Don't assert read twice in a row
                if (fifo_full_count > 0 && !fifo_read_lcl) begin
                    if (!must_wait_for_ready || string_ready[active_string]) begin
                        fifo_read_lcl <= 1'b1;

                        // Keep track of how many words we've shifted in. This will determine which
                        // bits are valid in the shift register.
                        if (fifo_shift_count == 2) begin
                            fifo_shift_count <= 1'b0;
                            fifo_shift_reg_primed <= 1'b1;
                        end else begin
                            fifo_shift_count <= fifo_shift_count + 1;
                        end

                        // If the last read completed the pixel, we need to wait for the next read.
                        must_wait_for_ready <= next_word_completes_pixel;
                    end

                    // active_string is coherent with fifo_read_lcl. The destination
                    // for FIFO data is registered and delayed below
                    if (must_wait_for_ready && string_ready[active_string]) begin
                        // Jump to next string if we'll complete a pixel with this read
                        if (active_string == (N_STRINGS - 1)) begin
                            active_string <= 0;
                        end else begin
                            active_string <= active_string + 1;
                        end
                    end
                end

                // Pixel data is valid after shift count 1 and 2. Precalculate whether the *next* shift
                // will complete the 24-bit pixel color.
                if (fifo_shift_count == 2 || (fifo_shift_count == 0 && fifo_shift_reg_primed)) begin
                    next_word_completes_pixel <= 1'b1;
                end else begin
                    next_word_completes_pixel <= 1'b0;
                end
            end
        end
    end

    reg shift_reg_sel;
    reg shift_reg_sel_q;
    reg shift_reg_sel_qq;
    always @(posedge clk)
    begin
        shift_reg_sel <= (fifo_shift_count == 1);
        shift_reg_sel_q <= shift_reg_sel;
        shift_reg_sel_qq <= shift_reg_sel_q;
    end

    reg next_word_completes_pixel_q;
    reg next_word_completes_pixel_qq;
    // Active string needs to be delayed to be coherent with the data to drive data valid properly
    reg [$clog2(N_STRINGS)-1:0] fifo_data_destination_nx = 0;
    reg [$clog2(N_STRINGS)-1:0] fifo_data_destination = 0;

    always @(posedge clk)
    begin
        if (reset || ~frame_active) begin
            next_word_completes_pixel_q <= 1'b0;
            next_word_completes_pixel_qq <= 1'b0;
            fifo_data_destination_nx <= 0;
            fifo_data_destination <= 0;
        end else begin
            fifo_data_destination_nx <= active_string;
            fifo_data_destination <= fifo_data_destination_nx;
            next_word_completes_pixel_q <= next_word_completes_pixel;
            next_word_completes_pixel_qq <= next_word_completes_pixel_q;
        end
    end

    reg [N_STRINGS-1:0] shift_data_valid = 0;
    reg [47:0] fifo_shift_reg = 0;

    always @(posedge clk)
    begin
        if (reset || ~frame_active) begin
            shift_data_valid <= 0;
            fifo_shift_reg <= 0;
        end else begin
            if (fifo_data_valid || flush_shift_reg) begin
                // Write data to top of shift register and shift down
                fifo_shift_reg <= { fifo_data, fifo_shift_reg[47:16] };
                shift_data_valid[fifo_data_destination] <= next_word_completes_pixel_qq;
            end else if (string_ready[fifo_data_destination]) begin
                shift_data_valid <= 0;
            end
        end
    end

    wire [23:0] shift_data;
    assign shift_data = shift_reg_sel_qq ? fifo_shift_reg[31:8] : fifo_shift_reg[24:0];

    reg [$clog2(N_LEDS_PER_STRING+1)-1:0] init_pixels_remaining;
    reg init_active;
    reg init_data_valid;

    always @(posedge clk)
    begin
        if (reset) begin
            init_pixels_remaining <= N_LEDS_PER_STRING;
            init_active <= 1'b1;
            init_data_valid <= 1'b0;
        end else begin
            // Strobes
            init_data_valid <= 1'b0;

            if (init_active && !string_active && !init_data_valid) begin
                if (init_pixels_remaining > 0) begin
                    init_pixels_remaining <= init_pixels_remaining - 1;
                    init_data_valid <= 1'b1;
                end else begin
                    init_active <= 1'b0;
                end
            end
        end
    end

    wire [23:0] pxl_data;
    assign pxl_data = init_active ? INIT_COLOR : shift_data;

    genvar string;
    generate
        for (string = 0; string < N_STRINGS; string = string + 1) begin
            wire pxl_data_valid;
            assign pxl_data_valid = init_active ? init_data_valid : shift_data_valid[string];

            string_driver #(
                .CLK_PERIOD_NS(50),
                .DATA_WIDTH(24)
            ) string_driverx (
                .clk(clk),
                .pixel_data(pxl_data),
                .pixel_data_valid(pxl_data_valid),
                .h_blank(h_blank_q),
                .sdi(led_sdi[string]),
                .string_ready(string_ready[string])
            );
        end
    endgenerate

    // Assert string_active if any string is busy
	assign string_active = ~(&string_ready);

endmodule