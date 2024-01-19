/*
 * The event_xing module safely crosses an event signals between unrelated clock
 * domains. It does this by toggling a flip-flop on the IClk domain every cycle ievent
 * asserts. That toggle flop is then double-synchronized to the OClk clock domain.
 * An edge detector then drives oEvent, asserting oEvent when a toggle is detected.
 * Another toggle-flop on the OClk domain toggles when an edge is detected on the
 * incoming toggle signal. That is then double-synchronized back to the IClk domain.
 * When the outgoing and incoming toggle flops on the IClk domain match, no events
 * are in flight and the component is ready for ievent to assert. If the flops do
 * not match, then an event (or toggle or edge) is in flight between clock domains
 * and ievent should not be asserted or else the pulse will be lost.
 */

module event_xing(
    // The input reset
    input wire logic ireset,
      // The input clock. All i* signals are synchronous to this clock
    input wire logic iclk,
    // Indicates that this component is ready for ievent to assert again.
    output var logic iready,
    // Asserts for a single cycle to indicate a particular event has occurred.
    input wire logic ievent,

    // The output reset
    input wire logic oreset,
    // The output clock. All o* signals are synchronous to this clock
    input wire logic oclk,
    // Asserts for a single cycle to indicate that ievent has asserted.
    output var logic oevent
);

    logic inear_toggle;
    logic ifar_toggle_ms, ifar_toggle;

    logic onear_toggle;
    logic ofar_toggle_ms, ofar_toggle, ofar_toggle_q;

    // Toggle our local toggle flop if the incoming event is signaled and
    // the remote side is ready to accept the event.
    always_ff @(posedge iclk) begin : itoggle_blk
        if (ireset) begin
            inear_toggle <= 1'b0;
        end else begin
            //synthesis translate_off
            assert (!ievent || iready)
                else $error("Event occurred before EventXing core was ready");
            //synthesis translate_on
            if (iready && ievent)
                inear_toggle <= ~inear_toggle;
        end
    end

    // OClk toggle signal is immediately returned to indicate ready. Holdoff
    // would occur here if we needed to wait for something to happen on the
    // oclk side.
    assign onear_toggle = ofar_toggle;

    always_ff @(posedge oclk) begin : odblsync
        if (oreset) begin
            ofar_toggle_ms <= 1'b0;
            ofar_toggle <= 1'b0;
            ofar_toggle_q <= 1'b0;
        end else begin
            ofar_toggle_ms <= inear_toggle;
            ofar_toggle <= ofar_toggle_ms;
            ofar_toggle_q <= ofar_toggle;
        end
    end

    always_ff @(posedge iclk) begin : IDblSync
        if (ireset) begin
            ifar_toggle_ms <= 1'b0;
            ifar_toggle <= 1'b0;
        end else begin
            ifar_toggle_ms <= onear_toggle;
            ifar_toggle <= ifar_toggle_ms;
        end
    end

    // The event is observed on the remote side if we saw the toggle signal flip
    assign oevent = (ofar_toggle != ofar_toggle_q);

    // The IClk side is ready if the sent and received toggles match
    assign iready = (ifar_toggle == inear_toggle);

endmodule