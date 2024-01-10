module tb_led_top;
    import uvm_pkg::*;
    import pkg_led_top_test::*;
    import pkg_gpmc_config::*;
    //import questa_uvm_pkg::*;

    bit clk_100;
    bit fclk;
    logic [22:0] color_led_sdi;
    logic [3:0] white_led_sdi;
    logic [3:0] led;
    logic glbl_reset;

    gpmc_if #(.ADDR_WIDTH(21)) gpmc_iface();
    gpmc_config #(.ADDR_WIDTH(21)) cfg;

    always #5 clk_100 <= ~clk_100;
    always #5 fclk <= ~fclk;

    assign gpmc_iface.fclk = fclk;

    top #(
    ) dut (
        .glbl_reset(glbl_reset),
        .clk_100(clk_100),

        .led(led),

        .gpmc_ad(gpmc_iface.data),
        .gpmc_advn(gpmc_iface.adv_n_ale),
        .gpmc_csn1(gpmc_iface.cs_n[1]),
        .gpmc_wein(gpmc_iface.we_n),
        .gpmc_oen(gpmc_iface.oe_n_re_n),
        .gpmc_clk(gpmc_iface.clk),

        .color_led_sdi(color_led_sdi),
        .white_led_sdi(white_led_sdi)
    );

    initial begin
        cfg = gpmc_config#(.ADDR_WIDTH(21))::type_id::create("cfg", null);
        cfg.vif = gpmc_iface;
        uvm_config_db#(gpmc_config#(.ADDR_WIDTH(21)))::set(null, "", "gpmc_cfg", cfg);
        run_test("led_top_test");
    end

    initial begin
        // Minimum reset pulse width is 1 us
        gpmc_iface.cs_n = 16'hFF;
        glbl_reset <= 1'b1;
        #1023ns;
        glbl_reset <= 1'b0;
    end

endmodule