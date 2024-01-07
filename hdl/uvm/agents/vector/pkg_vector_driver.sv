`include "uvm_macros.svh"

package pkg_vector_driver;
    import uvm_pkg::*;
    import pkg_vector_item::*;

    class vector_driver extends uvm_driver#(vector_item);
        `uvm_component_utils(vector_driver)

        virtual vector_if vif;

        function new(string name="vector_driver", uvm_component parent = null);
            super.new(name, parent);
        endfunction

        virtual function void build_phase(uvm_phase phase);
            super.build_phase(phase);

            if(!uvm_config_db#(virtual vector_if)::get(this, "", "vif", vif))
                `uvm_fatal(get_type_name(), "Could not get vector interface")
        endfunction

        virtual task run_phase(uvm_phase phase);
            vector_item req;
            super.run_phase(phase);

            forever begin
                seq_item_port.get_next_item(req);
                drive_item(req);
                seq_item_port.item_done();
            end
        endtask

        virtual task drive_item(vector_item req);
            @(posedge vif.clk);
            vif.data <= req.data;
        endtask
    endclass

endpackage