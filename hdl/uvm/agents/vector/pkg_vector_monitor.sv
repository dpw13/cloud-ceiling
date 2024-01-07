`include "uvm_macros.svh"

package pkg_vector_monitor;
    import uvm_pkg::*;
    import pkg_vector_item::*;

    class vector_monitor extends uvm_monitor;
        `uvm_component_utils(vector_monitor)

        virtual vector_if vif;

        uvm_analysis_port#(vector_item) analysis_port;

        function new(string name="vector_monitor", uvm_component parent = null);
            super.new(name, parent);
        endfunction

        virtual function void build_phase(uvm_phase phase);
            super.build_phase(phase);

            analysis_port = new("analysis_port", this);

            if(!uvm_config_db#(virtual vector_if)::get(this, "", "vif", vif))
                `uvm_fatal(get_type_name(), "Could not get vector interface")
        endfunction

        virtual task  run_phase(uvm_phase phase);
            vector_item req = new;

            super.run_phase(phase);

            forever begin
                @(posedge vif.clk);
                req.data = vif.data;
                analysis_port.write(req);
            end
        endtask
    endclass

endpackage
