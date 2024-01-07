`include "uvm_macros.svh"

package pkg_gpmc_driver;
    import uvm_pkg::*;
    import pkg_gpmc_config::*;

    class gpmc_driver #(
        parameter ADDR_WIDTH=21,
        parameter DATA_WIDTH=16
    ) extends uvm_driver#(uvm_tlm_generic_payload);
        `uvm_component_utils(gpmc_driver)

        gpmc_config cfg;
        virtual gpmc_if #(.ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH)) vif;

        function new(string name="gpmc_driver", uvm_component parent = null);
            super.new(name, parent);
        endfunction

        virtual function void build_phase(uvm_phase phase);
            super.build_phase(phase);

            if(!uvm_config_db#(virtual gpmc_config)::get(this, "", "gpmc_cfg", cfg))
                `uvm_fatal(get_type_name(), "Could not get GPMC config")
        endfunction

        virtual function void connect_phase(uvm_phase phase);
            vif = cfg.vif;
        endfunction;

        virtual task run_phase(uvm_phase phase);
            uvm_tlm_generic_payload req;
            super.run_phase(phase);

            forever begin
                seq_item_port.get_next_item(req);
                drive_item(req);
                seq_item_port.item_done();
            end
        endtask

        virtual task drive_item(uvm_tlm_generic_payload req);
            @(posedge vif.clk);
        endtask
    endclass

endpackage