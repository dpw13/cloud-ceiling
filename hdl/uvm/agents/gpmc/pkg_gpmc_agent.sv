`include "uvm_macros.svh"

package pkg_gpmc_agent;
    import uvm_pkg::*;
    import pkg_gpmc_driver::*;
    import pkg_gpmc_monitor::*;

    class gpmc_agent #(
        parameter ADDR_WIDTH=21,
        parameter DATA_WIDTH=16
    ) extends uvm_agent;
        `uvm_component_utils(gpmc_agent)

        gpmc_driver d0;
        gpmc_monitor m0;
        uvm_sequencer #(uvm_tlm_generic_payload) s0;

        function new(string name="gpmc_agent", uvm_component parent = null);
            super.new(name, parent);
        endfunction

        virtual function void build_phase(uvm_phase phase);
            super.build_phase(phase);

            if (get_is_active()) begin
                s0 = uvm_sequencer#(uvm_tlm_generic_payload)::type_id::create("s0", this);
                d0 = gpmc_driver#(.ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH))::type_id::create("d0", this);
            end
            m0 = gpmc_monitor#(.ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH))::type_id::create("m0", this);
        endfunction

        virtual function void connect_phase(uvm_phase phase);
            super.connect_phase(phase);

            if (get_is_active()) begin
                d0.seq_item_port.connect(s0.seq_item_export);
            end
        endfunction
    endclass //gpmc_agent extends uvm_agent
endpackage