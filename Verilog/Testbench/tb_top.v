/*
 * Top-level testbench.
 */

`timescale 1ns/1ns

module tb_top ();

parameter PERIOD_100 = 5; // 100 MHz
parameter PERIOD_FCLK = 2; // 250 MHz

reg reset_n;
reg clk_100;
reg gpmc_fclk; // internal ARM clock
reg gpmc_clk;
reg gpmc_clk_en;

wire [3:0] led;

wire [15:0] gpmc_ad;
wire [15:0] gpmc_ad_in;
reg  [15:0] gpmc_ad_out;
reg         gpmc_ad_oe;
reg         gpmc_advn;
reg         gpmc_csn1;
reg         gpmc_wein;
reg         gpmc_oen;

wire [1:0]  led_sdi;

assign gpmc_ad_in = gpmc_ad;
assign gpmc_ad = (gpmc_ad_oe) ? gpmc_ad_out : 16'bZ;

top #(
) dut (
    .reset_n(reset_n),
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

initial begin
    $display($time, "Startup");
    clk_100 <= 1'b0;
    gpmc_fclk <= 1'b0;
    gpmc_clk <= 1'b0;
    gpmc_clk_en <= 1'b0;
    reset_n <= 1'b0;
    gpmc_ad_out <= 16'h0;
    gpmc_ad_oe <= 1'b1;
    gpmc_advn <= 1'b1;
    gpmc_wein <= 1'b1;
    gpmc_csn1 <= 1'b1;
    gpmc_oen <= 1'b1;
    gpmc_clk <= 1'b0;

    // PLL reset must be at least 1 us
    #1005;
    reset_n <= 1'b1;
    // Run GPMC clock to allow synchronous resets to clear
    #100;
    gpmc_clk_en <= 1'b1;
    #100;
    gpmc_clk_en <= 1'b0;
    // It takes about another 7 us for the PLL to lock
    #7000;

    repeat (4) begin
        // GPMC write transaction
        @(posedge gpmc_fclk);
        gpmc_oen <= 1'b1;
        gpmc_csn1 <= 1'b1;
        gpmc_ad_oe <= 1'b1;
        gpmc_advn <= 1'b1; // address latch
        gpmc_wein <= 1'b0;
        gpmc_clk_en <= 1'b1;

        @(negedge gpmc_clk);
        gpmc_ad_out <= 16'h1000; // address phase
        gpmc_csn1 <= 1'b0;
        gpmc_advn <= 1'b0;

        @(negedge gpmc_clk);
        gpmc_ad_out <= 16'habcd; // data phase
        gpmc_advn <= 1'b1;

        @(negedge gpmc_clk);
        // Docs indicate that CS_n can rise after last clock pulse
        gpmc_ad_out <= 16'hXXXX;
        gpmc_csn1 <= 1'b1;

        @(negedge gpmc_clk);
        gpmc_clk_en <= 1'b0;
    end

    // Allow GPMC logic to progress
    #100;
    gpmc_clk_en <= 1'b1;
    #100;
    gpmc_clk_en <= 1'b0;

    #5000;
end

endmodule