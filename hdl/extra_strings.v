/*
 * Wrapper for multiple string_drivers. This module pops from the
 * pixel FIFO, shifts 16 bit words into 24-bit color tuples, and
 * queues the data for parallel string drivers.
 */

module extra_strings #(
    parameter N_STRINGS = 4,
    parameter N_LEDS_PER_STRING = 150
) (
    input clk,
    input reset,

    input color_valid,
    input [23:0] color_in,

    input  h_blank_in,
    output string_active,

    output [N_STRINGS-1:0] led_sdi
);

    localparam TOTAL_PIXELS = N_STRINGS*N_LEDS_PER_STRING;

    wire [N_STRINGS-1:0] string_ready;

    reg frame_active = 1'b0;
    reg [$clog2(N_LEDS_PER_STRING)-1:0] pixels_remaining = 0;

    reg h_blank = 1'b0;
    reg data_valid = 1'b0;
    reg do_init = 1'b1;

    always @(posedge clk)
    begin
        if (reset) begin
            do_init <= 1'b1;
            data_valid <= 1'b0;
            h_blank <= 1'b0;
            frame_active <= 1'b0;
            pixels_remaining <= N_LEDS_PER_STRING;
        end else begin
            // Strobes
            data_valid <= 1'b0;
            h_blank <= 1'b0;

            if (!string_active && !data_valid) begin
                if (color_valid || do_init) begin
                    do_init <= 1'b0;
                    frame_active <= 1'b1;
                    h_blank <= 1'b1;
                    pixels_remaining <= N_LEDS_PER_STRING - 1;
                end

                if (frame_active) begin
                    if (pixels_remaining > 0) begin
                        pixels_remaining <= pixels_remaining - 1;
                        data_valid <= 1'b1;
                    end else begin
                        frame_active <= 1'b0;
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

    genvar s;
    generate
        for (s = 0; s < N_STRINGS; s = s + 1) begin
            string_driver #(
                .CLK_PERIOD_NS(50),
                .DATA_WIDTH(24)
            ) string_driverx (
                .clk(clk),
                .pixel_data(color_in),
                .pixel_data_valid(data_valid),
                .h_blank(h_blank_q),
                .sdi(led_sdi[s]),
                .string_ready(string_ready[s])
            );
        end
    endgenerate

    // Assert string_active if any string is busy
	assign string_active = ~(&string_ready);

endmodule