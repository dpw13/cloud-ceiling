module cloud_ceiling_regmap_wrapper (
    input wire clk, reset,
    output wire pkg_cpu_if::cpu_if_i cpuif_i,
    input wire pkg_cpu_if::cpu_if_o cpuif_o,

    input wire cloud_ceiling_regmap_pkg::cloud_ceiling_regmap__in_t hwif_in,
    output wire cloud_ceiling_regmap_pkg::cloud_ceiling_regmap__out_t hwif_out
);

    cloud_ceiling_regmap regmap (
        .clk(clk),
        .rst(reset),
        .s_cpuif_req(cpuif_o.req),
        .s_cpuif_req_is_wr(cpuif_o.req_is_wr),
        .s_cpuif_addr(cpuif_o.addr),
        .s_cpuif_wr_data(cpuif_o.wr_data),
        .s_cpuif_wr_biten(cpuif_o.wr_biten),
        .s_cpuif_req_stall_wr(cpuif_i.req_stall_wr),
        .s_cpuif_req_stall_rd(cpuif_i.req_stall_rd),
        .s_cpuif_rd_ack(cpuif_i.rd_ack),
        .s_cpuif_rd_err(cpuif_i.rd_err),
        .s_cpuif_rd_data(cpuif_i.rd_data),
        .s_cpuif_wr_ack(cpuif_i.wr_ack),
        .s_cpuif_wr_err(cpuif_i.wr_err),

        .hwif_in(hwif_in),
        .hwif_out(hwif_out)
    );

endmodule