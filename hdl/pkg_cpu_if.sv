package pkg_cpu_if;
    /* 
     * For whatever reason, it appears that Surelog can't handle interfaces. The
     * symptom is that signals inside interfaces are "implicitly defined" and tend
     * to be only a single bit wide. To work around this, we'll use a struct for
     * passing this interface around.
     */
    typedef struct {
        logic req;
        logic req_is_wr;
        logic [12:0] addr;
        logic [15:0] wr_data;
        logic [15:0] wr_biten;
    } cpu_if_o;

    typedef struct {
        logic req_stall_wr;
        logic req_stall_rd;
        logic rd_ack;
        logic rd_err;
        logic [15:0] rd_data;
        logic wr_ack;
        logic wr_err;
    } cpu_if_i;
endpackage