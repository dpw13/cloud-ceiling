`include "uvm_macros.svh"

package pkg_vector_agent;
    import uvm_pkg::*;
    import pkg_vector_item::*;
    import pkg_vector_driver::*;
    import pkg_vector_monitor::*;

    class vector_agent extends uvm_agent;
        `uvm_component_utils(vector_agent)

        vector_driver d0;
        vector_monitor m0;
        uvm_sequencer #(vector_item) s0;

        function new(string name="vector_agent", uvm_component parent = null);
            super.new(name, parent);
        endfunction

        virtual function void build_phase(uvm_phase phase);
            super.build_phase(phase);

            if (get_is_active()) begin
                s0 = uvm_sequencer#(vector_item)::type_id::create("s0", this);
                d0 = vector_driver::type_id::create("d0", this);
            end
            m0 = vector_monitor::type_id::create("m0", this);
        endfunction

        virtual function void connect_phase(uvm_phase phase);
            super.connect_phase(phase);

            if (get_is_active()) begin
                d0.seq_item_port.connect(s0.seq_item_export);
            end
        endfunction
    endclass //vector_agent extends uvm_agent
endpackage