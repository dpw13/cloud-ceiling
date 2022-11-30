/*
 * Top-level testbench.
 */

`timescale 1ns/1ns

module tb_top ();

parameter PERIOD_100 = 5; // 100 MHz
parameter PERIOD_FCLK = 10; // 50 MHz, producing 25 MHz GPMC bus
parameter GPMC_TCO = 0; // Delay data outputs on GPMC bus after GPMC clock

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

wire [1:0]  led_sdi;

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

task gpmc_wr (
    input [16:0] addr,
    input [15:0] data
);
    begin
        // The timing below is based on the actual timing produced by the BBB

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

initial begin

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

    repeat (4) begin
        // Write pixel fifo data
        gpmc_wr(16'h1000, $random);
    end

    // Allow GPMC logic to progress
    #100;
    gpmc_clk_en <= 1'b1;
    #100;
    gpmc_clk_en <= 1'b0;

    #150_000;
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

    #10000;
    $finish();
end

endmodule