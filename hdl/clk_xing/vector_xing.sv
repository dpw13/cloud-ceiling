// The vector_xing module safely moves correlated data between clock domains. It
// implements this by registering iData when iPush asserts and sending a pulse across
// to the OClk domain using the event_xing core. Once the event is seen on the OClk
// domain, we know that iData has been stable for several OClk cycles and can be
// safely registered on the OClk domain.
//
// @see work.event_xing

module vector_xing#(
    // The width of the data to move between clock domains
    parameter int DATA_WIDTH = 32
) (
    // The input clock. All i* signals are synchronous to this clock
    input wire logic iclk,
    // The data to transmit
    input wire logic[DATA_WIDTH-1:0] idata,
    // Holdoff for iPush. Asserts if the component is ready for new data
    output wire logic iready,
    // Qualifies iData and indicates that iData should be sent to the OClk domain
    input wire logic ipush,

    // The output reset
    input wire logic oreset,
    // The output clock. All o* signals are synchronous to this clock
    input wire logic oclk,
    // The transmitted data
    output var logic[DATA_WIDTH-1:0] odata,
    // Asserts for a single cycle when odata has been updated
    output var logic odata_valid
);
    logic[DATA_WIDTH-1:0] idata_q;
    logic oevent;

    event_xing push_sync (
        .ireset(ireset),
        .iclk(iclk),
        .ievent(ipush),
        .iready(iready),

        .oreset(oreset),
        .oclk(oclk),
        .oevent(oevent)
    );

    // We need to register data on the IClk side so we're positive it's stable when
    // sending to the remote clock domain
    always_ff @( posedge iclk ) begin : reg_data
        if (ireset) begin
            idata_q <= '0;
        end else begin
            if (iready && ipush)
                idata_q <= idata;
        end
    end

    // Register data on the OClk domain only when we know it's safe to do so. iDataQ
    // is guaranteed to be stable when oEvent asserts.
    always_ff @( posedge oclk ) begin : out_data
        if (oreset) begin
            odata_valid <= 1'b0;
            odata <= '0;
        end else begin
            odata_valid <= oevent;
            if (oevent)
                odata <= idata_q;
        end
    end

endmodule