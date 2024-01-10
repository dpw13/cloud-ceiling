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

        function int find_cs_by_addr(bit [63:0] addr);
            foreach (cfg.cs_config[i]) begin
                if (cfg.cs_config[i].in_range(addr))
                    return i;
            end

            return -1;
        endfunction

        virtual task drive_item(uvm_tlm_generic_payload req);
            int cs_id = find_cs_by_addr(req.get_address());
            gpmc_cs_config cs_cfg;
            int cycle = 0;

            if (cs_id < 0) begin
                `uvm_warning(get_type_name(), $sformatf("Address 0x%0x not mapped to GPMC range", req.get_address()))
                req.set_response_status(UVM_TLM_ADDRESS_ERROR_RESPONSE);
                return;
            end
            cs_cfg = cfg.cs_config[cs_id];

            // Align to rising edge of FCLK
            @(posedge vif.fclk);
            `uvm_info(get_type_name(), $sformatf("Register request %s using %s", req.convert2string(), cs_cfg.convert2string()), UVM_LOW)

            while (1) begin
                if (cycle == cs_cfg.cs_on_time)
                    vif.cs_n[cs_id] <= 1'b0;

                if (cs_cfg.mux_addr_data == aad_mux) begin
                    if (cycle == cs_cfg.adv_aad_mux_on_time) begin
                        bit [63:0] addr = req.get_address();
                        vif.adv_n_ale <= 1'b0;
                        `uvm_info(get_type_name(), "Driving AD", UVM_LOW)
                        vif.driver_cb.data <= addr[DATA_WIDTH +: DATA_WIDTH];
                    end

                    if (cycle == cs_cfg.oe_aad_mux_on_time) begin
                        bit [63:0] addr = req.get_address();
                        vif.oe_n_re_n <= 1'b0;
                        `uvm_info(get_type_name(), "Driving AD", UVM_LOW)
                        vif.driver_cb.data <= addr[DATA_WIDTH +: DATA_WIDTH];
                    end

                    if (cycle == cs_cfg.oe_aad_mux_off_time) begin
                        `uvm_info(get_type_name(), "Tristating data", UVM_LOW)
                        vif.oe_n_re_n <= 1'b1;
                        vif.driver_cb.data <= 'z;
                    end
                end

                if (cycle == cs_cfg.adv_on_time) begin
                    bit [63:0] addr = req.get_address();
                    vif.adv_n_ale <= 1'b0;
                    case (cs_cfg.mux_addr_data)
                        no_mux: begin
                            `uvm_info(get_type_name(), "Driving addr", UVM_LOW)
                            vif.addr <= addr[ADDR_WIDTH-1:0];
                        end
                        ad_mux: begin
                            `uvm_info(get_type_name(), $sformatf("Driving AD with %0x", addr[0 +: DATA_WIDTH]), UVM_LOW)
                            vif.driver_cb.data <= addr[0 +: DATA_WIDTH];
                        end
                        aad_mux:
                            `uvm_info(get_type_name(), "AAD mode not fully supported", UVM_LOW)
                    endcase
                end

                if (req.is_read()) begin
                    if (cycle == cs_cfg.cs_rd_off_time)
                        vif.cs_n[cs_id] <= 1'b1;

                    if (cycle == cs_cfg.adv_aad_mux_rd_off_time && cs_cfg.mux_addr_data == aad_mux) begin
                        vif.adv_n_ale <= 1'b1;
                        vif.oe_n_re_n <= 1'b1;
                        `uvm_info(get_type_name(), "Tristating data", UVM_LOW)
                        vif.driver_cb.data <= 'z;
                    end

                    if (cycle == cs_cfg.adv_rd_off_time) begin
                        vif.adv_n_ale <= 1'b1;
                        // Tristate data if address muxed onto data
                        if (cs_cfg.mux_addr_data != no_mux) begin
                            `uvm_info(get_type_name(), "Tristating data", UVM_LOW)
                            vif.driver_cb.data <= 'z;
                        end
                    end

                    if (cycle == cs_cfg.oe_on_time)
                        vif.oe_n_re_n <= 1'b0;
                    if (cycle == cs_cfg.oe_off_time) begin
                        vif.oe_n_re_n <= 1'b1;
                        `uvm_info(get_type_name(), "Tristating data", UVM_LOW)
                        vif.driver_cb.data <= 'z;
                    end

                    if (cycle == cs_cfg.rd_access_time) begin
                        byte unsigned data[] = new[2];
                        data[0] = vif.driver_cb.data[7:0];
                        data[1] = vif.driver_cb.data[15:8];
                        req.set_data_length(2);
                        req.set_data(data);
                    end

                    // TODO: See SPRUH73Q Fig 7-44 for burst read timing diagrams

                    if (cycle == cs_cfg.rd_cycle_time)
                        break;
                end

                if (req.is_write()) begin
                    if (cycle == cs_cfg.cs_wr_off_time)
                        vif.cs_n[cs_id] <= 1'b1;

                    if (cs_cfg.mux_addr_data == aad_mux) begin
                        if (cycle == cs_cfg.adv_aad_mux_wr_off_time) begin
                            // The spec is unclear on when the data lines tristate in AAD
                            // mode, so we tristate it at the first off time.
                            vif.adv_n_ale <= 1'b1;
                            vif.driver_cb.data <= 'z;
                        end
                    end

                    if (cycle == cs_cfg.adv_wr_off_time) begin
                        vif.adv_n_ale <= 1'b1;
                        // Tristate data if address muxed onto data
                        if (cs_cfg.mux_addr_data != no_mux)
                            vif.driver_cb.data <= 'z;
                    end

                    if (cycle == cs_cfg.we_on_time)
                        vif.we_n <= 1'b0;
                    if (cycle == cs_cfg.we_off_time)
                        vif.we_n <= 1'b1;
                    if (cycle == cs_cfg.wr_data_on_ad_mux_bus)
                        vif.driver_cb.data <= {req.m_data[0], req.m_data[1]};

                    // TODO: See SPRUH73Q Fig 7-22 and 7-23 for burst write timing diagrams

                    if (cycle == cs_cfg.wr_cycle_time)
                        break;
                end

                // Update clock and pass time
                if (cs_cfg.gpmc_fclk_divider == div_1x) begin
                    // Special case the 1x multiplier
                    vif.clk <= 1'b1;
                    @(negedge vif.fclk);
                    vif.clk <= 1'b0;
                end else begin
                    if (cs_cfg.gpmc_fclk_divider == div_2x)
                        vif.clk <= ~vif.clk;
                    // div_3x not currently supported
                    if (cs_cfg.gpmc_fclk_divider == div_4x && (cycle % 2) == 0)
                        vif.clk <= ~vif.clk;
                end

                cycle++;
                @(posedge vif.fclk);
            end

            // TODO: This should actually be max(c2c delay, turnaround delay)
            repeat (cs_cfg.cycle_2_cycle_delay) @(posedge vif.fclk);

            req.set_response_status(UVM_TLM_OK_RESPONSE);
            vif.cs_n <= '1;
        endtask
    endclass

endpackage