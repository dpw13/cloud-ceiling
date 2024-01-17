module cloud_ceiling_regmap_wrapper (
    cpu_if.dev cpuif,

    input wire cloud_ceiling_regmap_pkg::cloud_ceiling_regmap__in_t hwi,
    output wire cloud_ceiling_regmap_pkg::cloud_ceiling_regmap__out_t hwo
);

    cloud_ceiling_regmap regmap (
        .clk(cpuif.clk),
        .rst(cpuif.reset),
        .s_cpuif_req(cpuif.req),
        .s_cpuif_req_is_wr(cpuif.req_is_wr),
        .s_cpuif_addr(cpuif.addr),
        .s_cpuif_wr_data(cpuif.wr_data),
        .s_cpuif_wr_biten(cpuif.wr_biten),
        .s_cpuif_req_stall_wr(cpuif.req_stall_wr),
        .s_cpuif_req_stall_rd(cpuif.req_stall_rd),
        .s_cpuif_rd_ack(cpuif.rd_ack),
        .s_cpuif_rd_err(cpuif.rd_err),
        .s_cpuif_rd_data(cpuif.rd_data),
        .s_cpuif_wr_ack(cpuif.wr_ack),
        .s_cpuif_wr_err(cpuif.wr_err),

        .hwif_in(hwi),
        .hwif_out(hwo)
    );

endmodule