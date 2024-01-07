module tb_dflop;
    import uvm_pkg::*;
    import pkg_dflop_test::*;
    //import questa_uvm_pkg::*;

    bit clk;
    logic cEn = 1'b1;

    vector_if #(.WIDTH(1)) d_if(clk);
    vector_if #(.WIDTH(1)) q_if(clk);

    always #10 clk <= ~clk;

    dflop #(.WIDTH(1)) flop (
        .clk(clk),
        .cEn(cEn),
        .cD(d_if.data),
        .cQ(q_if.data)
    );

    initial begin
        uvm_config_db#(virtual vector_if#(.WIDTH(1)))::set(null, "", "d_vif", d_if);
        uvm_config_db#(virtual vector_if#(.WIDTH(1)))::set(null, "", "q_vif", q_if);
        run_test("dflop_test");
    end

endmodule