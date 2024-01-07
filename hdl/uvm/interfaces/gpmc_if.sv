interface gpmc_if #(
    parameter ADDR_WIDTH = 16,
    parameter DATA_WIDTH = 16,
    parameter CS_COUNT = 8
);
    bit fclk;
    bit clk;
    logic [ADDR_WIDTH-1:0] addr;
    wire [DATA_WIDTH-1:0] data;
    logic [CS_COUNT-1:0] cs_n;
    logic adv_n_ale;
    logic oe_n_re_n;
    logic we_n;
    logic be0_n_cle;
    logic be1_n;
    logic wp_n;
    logic wait_[3:0];
    logic dir;

    modport controller (
        output clk, addr, cs_n, adv_n_ale, oe_n_re_n, we_n, be0_n_cle, be1_n, wp_n, dir,
        input wait_, fclk
    );

    modport device (
        input clk, addr, cs_n, adv_n_ale, oe_n_re_n, we_n, be0_n_cle, be1_n, wp_n, dir,
        output wait_
    );
endinterface