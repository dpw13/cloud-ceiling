/*
 * Top-level testbench.
 */

`timescale 1ns/1ns

module tb_top ();

parameter PERIOD_100 = 5; // 100 MHz
parameter PERIOD_FCLK = 10; // 50 MHz, producing 25 MHz GPMC bus
parameter GPMC_TCO = 0; // Delay data outputs on GPMC bus after GPMC clock

localparam N_LEDS_PER_STRING = 8;
localparam N_STRINGS = 5;
localparam N_FRAMES = 3;

reg glbl_reset;
reg clk_100;
reg gpmc_fclk; // internal ARM clock
reg gpmc_clk;
reg gpmc_clk_en;

wire [3:0] led;

wire [15:0] gpmc_ad;
wire [15:0] gpmc_ad_in;
reg  [15:0] gpmc_ad_out;
reg         gpmc_advn;
reg         gpmc_csn1;
reg         gpmc_wein;
reg         gpmc_oen;

wire [22:0] led_sdi;

assign gpmc_ad_in = gpmc_ad;
assign gpmc_ad = (gpmc_oen) ? gpmc_ad_out : 16'bZ;

top #(
) dut (
    .glbl_reset(glbl_reset),
    .clk_100(clk_100),

    .led(led),

    .gpmc_ad(gpmc_ad),
    .gpmc_advn(gpmc_advn),
    .gpmc_csn1(gpmc_csn1),
    .gpmc_wein(gpmc_wein),
    .gpmc_oen(gpmc_oen),
    .gpmc_clk(gpmc_clk),

    .led_sdi(led_sdi)
);

always #PERIOD_100 clk_100=~clk_100;
always #PERIOD_FCLK gpmc_fclk=~gpmc_fclk;

always @(posedge gpmc_fclk) gpmc_clk <= (gpmc_clk_en) ? ~gpmc_clk : 1'b0;

// Store expected frame data
reg [7:0] frame_data[N_FRAMES-1:0][N_LEDS_PER_STRING*N_STRINGS*3-1:0];

localparam T0H_min = 400-150;
localparam T0H_max = 400+150;
localparam T1H_min = 800-150;
localparam T1H_max = 800+150;
localparam T0L_min = 850-150;
localparam T0L_max = 850+150;
localparam T1L_min = 450-150;
localparam T1L_max = 450+150;

genvar string;
for (string=0; string < N_STRINGS; string = string+1) begin
    // WS2812B model
    realtime sdi_rise, sdi_fall;
    realtime sdi_high, sdi_low;
    always @ (negedge led_sdi[string])
    begin
        sdi_fall <= $realtime();
    end

    reg [23:0] led_data = 0;
    reg [23:0] led_expected = 0;
    integer bit_count = 0;
    integer pixel_count = 0;
    integer frame_count = -1;

    always @ (posedge led_sdi[string])
    begin
        sdi_high = sdi_fall - sdi_rise;
        sdi_low = $realtime() - sdi_fall;
        sdi_rise = $realtime();

        if (sdi_low > 50_000) begin
            // We don't care about high time in this case
            $display("HBLANK string %d, start frame %d", string, frame_count + 1);
            led_data = 0;
            bit_count = 0;
            pixel_count = 0;
            frame_count = frame_count + 1;
        end else if (sdi_high > T0H_min && sdi_high < T0H_max && sdi_low > T0L_min && sdi_low < T0L_max) begin
            // shift up
            led_data = { led_data[22:0], 1'b0 };
            bit_count = bit_count + 1;
        end else if (sdi_high > T1H_min && sdi_high < T1H_max && sdi_low > T1L_min && sdi_low < T1L_max) begin
            led_data = { led_data[22:0], 1'b1 };
            bit_count = bit_count + 1;
        end else if ($realtime > 0) begin
            $display("ERROR: Invalid bit time on string %d at %t ns: %t high %t low", string, sdi_rise, sdi_high, sdi_low);
        end

        if (bit_count == 24) begin
            led_expected = { 
                frame_data[frame_count][3*(N_STRINGS*pixel_count+string)+2],
                frame_data[frame_count][3*(N_STRINGS*pixel_count+string)+1],
                frame_data[frame_count][3*(N_STRINGS*pixel_count+string)+0] };

            if (led_data != led_expected) begin
                $display("ERROR: Data mismatch frame %d string %d pixel %d: got 0x%06x expected 0x%06x", frame_count, string, pixel_count, led_data, led_expected);
                $finish();
            end else begin
                $display("Data MATCH frame %d string %d pixel %d: got 0x%06x expected 0x%06x", frame_count, string, pixel_count, led_data, led_expected);
            end
            pixel_count = pixel_count + 1;
            bit_count = 0;
        end
    end
end

task gpmc_wr (
    input [16:0] addr,
    input [15:0] data
);
    begin
        // The timing below is based on the actual timing produced by the BBB
        $display("WR: *0x%04x = 0x%04x", addr, data);

        // GPMC write transaction
        @(negedge gpmc_fclk);
        gpmc_clk_en <= 1'b1;

        @(posedge gpmc_clk);
        #GPMC_TCO;
        gpmc_ad_out <= addr[16:1]; // address phase
        gpmc_csn1 <= 1'b0;
        gpmc_advn <= 1'b0;

        @(posedge gpmc_clk);
        #GPMC_TCO;
        gpmc_ad_out <= data; // data phase
        gpmc_wein <= 1'b0;
        gpmc_advn <= 1'b1;

        @(posedge gpmc_clk);
        #GPMC_TCO;
        gpmc_ad_out <= 16'hXXXX;
        gpmc_wein <= 1'b1;
        gpmc_csn1 <= 1'b1;
        gpmc_clk_en <= 1'b0;
    end
endtask

task gpmc_rd (
    input  [16:0] addr,
    output [15:0] data
);
    begin
        // GPMC read transaction
        @(posedge gpmc_fclk);
        gpmc_clk_en <= 1'b1;
        gpmc_csn1 <= 1'b1;

        @(posedge gpmc_fclk);
        gpmc_ad_out <= addr[16:1]; // address phase
        gpmc_advn <= 1'b0;
        gpmc_csn1 <= 1'b0;

        repeat (2) @(posedge gpmc_fclk);
        #GPMC_TCO;
        gpmc_ad_out <= 16'hXXXX; // data phase
        gpmc_oen <= 1'b0;
        gpmc_advn <= 1'b1;

        repeat (6) @(posedge gpmc_fclk);
        #GPMC_TCO;
        // Data latched at 100 ns
        data <= gpmc_ad_in;

        repeat (2) @(posedge gpmc_fclk);
        #GPMC_TCO;
        // Release and invalidate bus
        gpmc_ad_out <= 16'hXXXX;
        gpmc_oen <= 1'b1;
        gpmc_csn1 <= 1'b1;
        gpmc_clk_en <= 1'b0;

        repeat (2) @(posedge gpmc_fclk);
        gpmc_advn <= 1'b0; // idles low
        #1;
    end
endtask

reg [15:0] temp_data;
integer word, frame, i;

initial begin

    for (frame=0; frame < N_FRAMES; frame = frame+1) begin
        for (i=0; i < N_LEDS_PER_STRING*N_STRINGS*3; i = i + 1) begin
            frame_data[frame][i] = $random();
        end
    end

    $display($time, "Startup");
    clk_100 <= 1'b0;
    glbl_reset <= 1'b1;
    gpmc_fclk <= 1'b0;
    gpmc_clk <= 1'b0;
    gpmc_clk_en <= 1'b0;
    gpmc_ad_out <= 16'h0;
    gpmc_advn <= 1'b1;
    gpmc_wein <= 1'b1;
    gpmc_csn1 <= 1'b1;
    gpmc_oen <= 1'b1;
    gpmc_clk <= 1'b0;

    /*
     * Timings from BW-ICE40CapeV2-01-00A0.dts in BeagleWire repo
     *
     * Clock period: 20 ns (50 MHz)
     *
     * I believe the following timings are relative to the start of the transfer
     *
     * CS assertion time: 0 ns
     * CS deassertion for reads: 100 ns
     * CS deassertion for writes: 40 ns
     *
     * ADV_n assertion time: 0 ns
     * ADV_n deassertion for reads: 20 ns
     * ADV_n deassertion for writes: 20 ns
     *
     * WE_n assertion time: 20 ns
     * WE_n deassertion time: 40 ns
     *
     * OE assertion time: 20 ns
     * OE deassertion time: 100 ns
     *
     * "Multiple access word delay": 20 ns (cycles per word?) 
     * Data valid at: 80 ns (access-ns)
     * Total read cycle time: 120 ns
     * Total write cycle time: 60 ns
     *
     * Write access time (data captured at): 40 ns
     * Write data on muxed AD bus at: 20 ns
     *
     * Bus turnaround time: 0 ns (default)
     * Note that there appears to be an extra cycle with CS deasserted built into the
     * parameters above, so CS is guaranteed to deassert for at least one cycle.
     */

    // PLL reset must be at least 1 us
    #1005;
    glbl_reset <= 1'b0;
    // Run GPMC clock to allow synchronous resets to clear
    #100;
    gpmc_clk_en <= 1'b1;
    #100;
    gpmc_clk_en <= 1'b0;
    // It takes about another 7 us for the PLL to lock
    #7000;

    gpmc_rd(16'h0000, temp_data);
    #100;
    $display("ID reg: %04x", temp_data);
    gpmc_rd(16'h0002, temp_data);
    #100;
    $display("Scratch reg: %04x", temp_data);
    gpmc_wr(16'h0002, 16'h4321);
    #100;
    gpmc_rd(16'h0002, temp_data);
    #100;
    $display("Scratch reg: %04x", temp_data);

    // One frame
    for(word = 0; word < N_LEDS_PER_STRING*N_STRINGS*3/2; word = word + 1) begin
        temp_data[ 7:0] = frame_data[0][2*word + 0];
        temp_data[15:8] = frame_data[0][2*word + 1];
        gpmc_wr(16'h1000, temp_data);
    end
    // Access some other register to get the GPMC data through
    gpmc_rd(16'h0000, temp_data);

    #300_000;

    // Two frames
    for(frame = 1; frame < 3; frame = frame + 1) begin
        for(word = 0; word < N_LEDS_PER_STRING*N_STRINGS*3/2; word = word + 1) begin
            temp_data[ 7:0] = frame_data[frame][2*word + 0];
            temp_data[15:8] = frame_data[frame][2*word + 1];
            gpmc_wr(16'h1000, temp_data);
        end
    end

    // Access some other register to get the GPMC data through
    gpmc_rd(16'h0000, temp_data);

    // Allow GPMC logic to progress
    #100;
    gpmc_clk_en <= 1'b1;
    #100;
    gpmc_clk_en <= 1'b0;

    #300_000;
    // hblank
    gpmc_wr(16'h14, 1);
    #150_000;
    // Write pixel fifo data
    gpmc_wr(16'h1000, $random);

    // Allow GPMC logic to progress
    #100;
    gpmc_clk_en <= 1'b1;
    #100;
    gpmc_clk_en <= 1'b0;

    #300_000;
    $finish();
end

endmodule