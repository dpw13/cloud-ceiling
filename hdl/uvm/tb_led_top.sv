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

    wire [15:0] gpmc_ad;

    top #(
    ) dut (
        .glbl_reset(glbl_reset),
        .clk_100(clk_100),

        .led(led),

        .gpmc_ad(gpmc_ad),
        .gpmc_advn(gpmc_iface.adv_n_ale),
        .gpmc_csn1(gpmc_iface.cs_n[1]),
        .gpmc_wein(gpmc_iface.we_n),
        .gpmc_oen(gpmc_iface.oe_n_re_n),
        .gpmc_clk(gpmc_iface.clk),

        .color_led_sdi(color_led_sdi),
        .white_led_sdi(white_led_sdi)
    );

    assign gpmc_iface.data_i = gpmc_ad;
    assign gpmc_ad = gpmc_iface.oe_n_re_n == 1'b1 ? gpmc_iface.data_o : 'z;

    initial begin
        cfg = gpmc_config#(.ADDR_WIDTH(21))::type_id::create("cfg", null);
        cfg.cs_config[1].set_range(64'h0, (1 << 24));
        cfg.cs_config[1].read_type = sync;
        cfg.cs_config[1].write_type = sync;
        cfg.cs_config[1].device_size = size_16_bit;
        cfg.cs_config[1].mux_addr_data = ad_mux;
        cfg.cs_config[1].gpmc_fclk_divider = div_4x;
        cfg.cs_config[1].clk_activation_time = 2;

        // Timing. The CLK is FCLK/4, so all these timings must be
        // multiplied by 4 to be in units of CLK.
        cfg.cs_config[1].cs_on_time = 0;
        cfg.cs_config[1].cs_wr_off_time = 8;
        cfg.cs_config[1].cs_rd_off_time = 12;

        cfg.cs_config[1].adv_on_time = 0;
        cfg.cs_config[1].adv_wr_off_time = 4;
        cfg.cs_config[1].adv_rd_off_time = 4;

        cfg.cs_config[1].we_on_time = 4;
        cfg.cs_config[1].we_off_time = 8;

        cfg.cs_config[1].oe_on_time = 4;
        cfg.cs_config[1].oe_off_time = 12;

        cfg.cs_config[1].page_burst_access_time = 4;
        cfg.cs_config[1].rd_access_time = 12;
        cfg.cs_config[1].rd_cycle_time = 14;
        cfg.cs_config[1].wr_cycle_time = 10;

        cfg.cs_config[1].wr_access_time = 8;
        cfg.cs_config[1].wr_data_on_ad_mux_bus = 4;
        cfg.cs_config[1].cycle_2_cycle_delay = 0;
        cfg.cs_config[1].cycle_2_cycle_same_cs_en = 1;
        cfg.cs_config[1].cycle_2_cycle_diff_cs_en = 1;

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