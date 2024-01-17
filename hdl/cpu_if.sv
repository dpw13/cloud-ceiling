interface cpu_if #(
    parameter ADDR_WIDTH = 16,
    parameter DATA_WIDTH = 16
) (
    input bit reset,
    input bit clk
);
    wire req;
    wire req_is_wr;
    wire [ADDR_WIDTH-1:0] addr;
    wire [DATA_WIDTH-1:0] wr_data;
    wire [DATA_WIDTH-1:0] wr_biten;
    wire req_stall_wr;
    wire req_stall_rd;
    wire rd_ack;
    wire rd_err;
    wire [DATA_WIDTH-1:0] rd_data;
    wire wr_ack;
    wire wr_err;

    modport cpu (
        output req,
        output req_is_wr,
        output addr,
        output wr_data,
        output wr_biten,
        input req_stall_wr,
        input req_stall_rd,
        input rd_ack,
        input rd_err,
        input rd_data,
        input wr_ack,
        input wr_err
    );

    modport dev (
        input req,
        input req_is_wr,
        input addr,
        input wr_data,
        input wr_biten,
        output req_stall_wr,
        output req_stall_rd,
        output rd_ack,
        output rd_err,
        output rd_data,
        output wr_ack,
        output wr_err
    );
endinterface