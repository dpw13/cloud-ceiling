`include "uvm_macros.svh"

package pkg_gpmc_driver;
    import uvm_pkg::*;
    import pkg_gpmc_config::*;

    class gpmc_driver #(
        parameter ADDR_WIDTH=21,
        parameter DATA_WIDTH=16
    ) extends uvm_driver#(uvm_tlm_generic_payload);
        `uvm_component_utils(gpmc_driver)

        gpmc_config #(.ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH)) cfg;
        virtual gpmc_if #(.ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH)) vif;

        function new(string name="gpmc_driver", uvm_component parent = null);
            super.new(name, parent);
        endfunction

        virtual function void build_phase(uvm_phase phase);
            super.build_phase(phase);

            if(!uvm_config_db#(gpmc_config#(.ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH)))::get(this, "", "gpmc_cfg", cfg))
                `uvm_fatal(get_type_name(), "Could not get GPMC config")
        endfunction

        virtual function void connect_phase(uvm_phase phase);
            vif = cfg.vif;
            vif.cs_n <= '1;
            vif.clk <= 1'b0;
            vif.adv_n_ale <= 1'b1;
            vif.oe_n_re_n <= 1'b1;
            vif.we_n <= 1'b1;
            vif.be0_n_cle <= 1'b1;
            vif.be1_n <= 1'b1;
            vif.driver_cb.data <= 'z;
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

        task tick(int div=4, int cnt=1);
            // TODO: proper clocking
            repeat (cnt) begin
                #1ns;
                vif.clk <= 1'b1;
                repeat (div) @(posedge vif.fclk);
                #1ns;
                vif.clk <= 1'b0;
                repeat (div) @(posedge vif.fclk);
            end
        endtask

        virtual task drive_item(uvm_tlm_generic_payload req);
            int cs_id = 1; // TODO: find CS from addr map

            `uvm_info(get_type_name(), $sformatf("Register request: %s", req.convert2string()), UVM_LOW)

            // TODO: proper generalized timing
            // This should basically just be an FCLK counter that twiddles bits at the
            // configured time.
            vif.cs_n[cs_id] <= 1'b0;
            // TODO: proper AD muxing
            vif.driver_cb.data <= req.m_address[15:0];
            vif.adv_n_ale <= 1'b0;
            tick();
            vif.driver_cb.data <= 'z;
            vif.adv_n_ale <= 1'b1;

            if (req.is_write()) begin
                // write
                vif.driver_cb.data <= {req.m_data[0], req.m_data[1]};
                vif.we_n <= 1'b0;
                tick();
                vif.we_n <= 1'b1;
                vif.driver_cb.data <= 'z;
                tick();
            end else begin
                byte unsigned data[] = new[2];
                // read
                tick();
                vif.oe_n_re_n <= 1'b0;
                tick(.cnt(2));
                vif.oe_n_re_n <= 1'b1;
                data[0] = vif.driver_cb.data[7:0];
                data[1] = vif.driver_cb.data[15:8];
                req.set_data_length(2);
                req.set_data(data);
            end

            req.set_response_status(UVM_TLM_OK_RESPONSE);
            vif.cs_n <= '1;
        endtask
    endclass

endpackage