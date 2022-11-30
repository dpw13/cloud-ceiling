/*
 * String driver module for a string of WS2812B LED drivers.
 */

module string_driver #(
    parameter CLK_PERIOD_NS = 100
) (
    input clk,

    input [23:0] pixel_data,
    input        pixel_data_valid,
    input        h_blank,
    output       string_ready,

    output       sdi
);

// Nominal data bit timing

// High time
localparam kT0H_ns = 400;
localparam kT1H_ns = 800;
// Low time
localparam kT0L_ns = 850;
localparam kT1L_ns = 450;
// Blank time
localparam kBlank_ns = 50000;

function integer get_count(input integer bit_period, clk_period);
    // Determine the minimum number of clock cycles for the bit
    // period. Round up.
    get_count = (bit_period + clk_period - 1)/clk_period;
endfunction

// 2 extra cycles of latency due to state machine construction.
localparam kT0H_Count = get_count(kT0H_ns, CLK_PERIOD_NS) - 2;
localparam kT1H_Count = get_count(kT1H_ns, CLK_PERIOD_NS) - 2;
localparam kT0L_Count = get_count(kT0L_ns, CLK_PERIOD_NS) - 2;
localparam kT1L_Count = get_count(kT1L_ns, CLK_PERIOD_NS) - 2;

localparam kHBlankCount = get_count(kBlank_ns, CLK_PERIOD_NS);

reg [23:0] shift_reg = 0;
reg        shift_done = 1'b0;
reg        shift_start = 1'b0;
reg        shift_ready = 1'b1;
reg  [4:0] bit_count = 0;

localparam IDLE = 0;
localparam BIT_HIGH = 1;
localparam BIT_LOW = 2;
localparam HBLANK = 3;

// Tick count width is determined by the longest pulse length, which
// is the hblank (reset) pulse. For a 10 MHz clock, the count is about
// 500.
reg [9:0] tick_count;
reg [1:0] bit_state = IDLE;

always @ (posedge clk)
begin
    shift_start <= 1'b0;

    if (pixel_data_valid) begin
        bit_count <= 25;
        shift_ready <= 1'b0;
        shift_reg <= pixel_data;
        shift_start <= 1'b1;
    end else if (shift_done) begin
        // MSB sent first, shift up
        shift_reg <= { shift_reg[22:0], 1'b0 };

        if (bit_count > 0) begin
            bit_count <= bit_count - 1;
            shift_start <= 1'b1;
        end
    end

    // This is pretty hacky. We advance shift_ready based on the total latency
    // to pixel_data_valid. This includes the FIFO latency and depends on a lot
    // of code outside of this file. It's not great, but it does allow us to
    // transmit pixel data without interruption.
    if (bit_count == 0 && bit_state == BIT_LOW && tick_count == 4) begin
        shift_ready <= 1'b1;
    end
end

reg       bit_ready = 1'b1;
reg       blank_ready = 1'b1;

reg       sdi_lcl = 1'b1;

// To save on resources we use the same counter for all pulse widths.
always @ (posedge clk)
begin
    shift_done <= 1'b0;

    case (bit_state)
        IDLE:
            begin
                if (shift_start) begin
                    bit_state <= BIT_HIGH;
                    sdi_lcl <= 1'b1;
                    if (shift_reg[23] == 1'b1) begin
                        tick_count <= kT1H_Count;
                    end else begin
                        tick_count <= kT0H_Count;
                    end
                end

                if (h_blank) begin
                    bit_state <= HBLANK;
                    tick_count <= kHBlankCount;
                    // the blanking/reset pulse is only low
                    sdi_lcl <= 1'b0;
                    // We have an extra ready signal for blanking
                    blank_ready <= 1'b0;
                end
            end
        BIT_HIGH:
            if (tick_count > 0) begin
                tick_count <= tick_count - 1;
            end else begin
                bit_state <= BIT_LOW;
                sdi_lcl <= 1'b0;
                if (shift_reg[23] == 1'b1) begin
                    tick_count <= kT1L_Count;
                end else begin
                    tick_count <= kT0L_Count;
                end
            end
        BIT_LOW:
            if (tick_count > 0) begin
                tick_count <= tick_count - 1;
            end else begin
                shift_done <= 1'b1;
                bit_state <= IDLE;
                // Bus idles high
                sdi_lcl <= 1'b1;
            end
        HBLANK:
            if (tick_count > 0) begin
                tick_count <= tick_count - 1;
                // Also advance blank_ready to make sure the first bit isn't stretched
                if (tick_count == 8) begin
                    // Indicate ready
                    blank_ready <= 1'b1;
                end
            end else begin
                shift_done <= 1'b1;
                bit_state <= IDLE;
                // Bus idles high
                sdi_lcl <= 1'b1;
            end
    endcase
end

assign sdi = sdi_lcl;
assign string_ready = shift_ready && blank_ready;

endmodule