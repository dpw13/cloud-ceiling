`include "uvm_macros.svh"

package pkg_gpmc_monitor;
    import uvm_pkg::*;
    import pkg_gpmc_config::*;

    class gpmc_monitor #(
        parameter ADDR_WIDTH=21,
        parameter DATA_WIDTH=16
    ) extends uvm_monitor;
        `uvm_component_utils(gpmc_monitor)

        gpmc_config #(.ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH)) cfg;
        virtual gpmc_if #(.ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH)) vif;

        // Separate analysis ports for each CS
        uvm_analysis_port#(uvm_tlm_generic_payload) analysis_port[7:0];

        function new(string name="gpmc_monitor", uvm_component parent = null);
            super.new(name, parent);
        endfunction

        virtual function void build_phase(uvm_phase phase);
            super.build_phase(phase);

            foreach (analysis_port[i])
                analysis_port[i] = new($sformatf("analysis_port[%0d]", i), this);

            if(!uvm_config_db#(gpmc_config#(.ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH)))::get(this, "", "gpmc_cfg", cfg))
                `uvm_fatal(get_type_name(), "Could not get GPMC config")

            // TODO: validate config
        endfunction

        virtual function void connect_phase(uvm_phase phase);
            vif = cfg.vif;
        endfunction;

        virtual task run_phase(uvm_phase phase);

            super.run_phase(phase);

            forever begin
                // Create new access each time
                uvm_tlm_generic_payload req = new;
                int cs_id = 0;
                bit cs_active = 1'b0;
                bit [63:0] addr = 0;
                byte unsigned payload[$];
                bit byte_enable[$];
                int wait_pin_id = -1;
                bit wait_active = 1'b0;
                gpmc_cs_config cs_cfg;
                int data_phase_countdown = -1;

                while (&vif.cs_n)
                    @(posedge vif.clk);

                cs_active = 1'b0;
                foreach(vif.cs_n[i]) begin
                    if (vif.cs_n[i] == 1'b0) begin
                        if (!cs_active) begin
                            cs_id = i;
                            cs_active = 1'b1;
                            cs_cfg = cfg.cs_config[i];
                            `uvm_info(get_type_name(), $sformatf("CS %0d active using config %s", i, cs_cfg.convert2string()), UVM_DEBUG)
                        end else begin
                            `uvm_error(get_type_name(), $sformatf("CS %0d and %0d asserted simultaneously", cs_id, i))
                        end
                    end
                end

                `uvm_info(get_type_name(), $sformatf("CS assert: %0x ID %0d active %0d", vif.cs_n, cs_id, cs_active), UVM_FULL)

                data_phase_countdown = -1;
                while (cs_active && vif.cs_n[cs_id] == 1'b0) begin
                    if (~vif.adv_n_ale) begin
                        int bit_offset;

                        if (~vif.oe_n_re_n) begin
                            // first AAD phase. The documentation isn't super clear about how
                            // the full address is muxed onto the A and D lines. Let's assume
                            // the specified addr and data width is used for each phase.
                            if (cs_cfg.mux_addr_data == no_mux) begin
                                bit_offset = ADDR_WIDTH;
                            end else begin
                                bit_offset = ADDR_WIDTH + DATA_WIDTH;
                            end
                        end else begin
                            // last AAD phase or first AD phase.
                            bit_offset = 0;
                        end


                        if (cs_cfg.mux_addr_data == no_mux) begin
                            // If address/data are not muxed, load the address only from the
                            // address lines.
                            addr[bit_offset +: ADDR_WIDTH] = vif.addr[0 +: ADDR_WIDTH];
                        end else begin
                            // If muxed, load address from data and address lines.
                            addr[bit_offset +: DATA_WIDTH] = vif.data_o[0 +: DATA_WIDTH];
                            addr[bit_offset + DATA_WIDTH +: ADDR_WIDTH] = vif.addr[0 +: ADDR_WIDTH];
                        end

                        `uvm_info(get_type_name(), $sformatf("CS %0d ADV_n ADDR %0x", cs_id, addr), UVM_DEBUG)
                    end else if (~vif.oe_n_re_n) begin
                        // if OEn asserts without ADVn, that indicates a read
                        // The GPMC read timing is specified relative to the start of CS. Compute
                        // the delay from OEn to a read.
                        assert (!req.is_write()) else
                            `uvm_error(get_type_name(), "OEn asserted after WEn")
                        if (data_phase_countdown == -1) begin
                            int rd_delay = cs_cfg.rd_access_time - cs_cfg.oe_on_time;
                            // Convert from FCLK period to CLK period
                            data_phase_countdown = rd_delay/(cs_cfg.gpmc_fclk_divider + 1);
                            `uvm_info(get_type_name(), $sformatf("CS %0d OE_n, delay %0d FCLKs (%0d CLKs)", cs_id, rd_delay, data_phase_countdown), UVM_DEBUG)
                            req.set_read();
                            req.set_address(addr);

                            if (cs_cfg.wait_read_monitoring) begin
                                wait_pin_id = cs_cfg.wait_pin_select;
                                wait_active = cfg.wait_pin_polarity[wait_pin_id];
                            end else begin
                                wait_pin_id = -1;
                            end
                        end
                    end // address phase or read command

                    // Note that one of the examples in the AM335x TRM indicates that a single cycle of
                    // WEn asserting may be sufficient to indicate a write. To be as general as possible,
                    // I'm assuming that a single assertion of we_n is sufficient to indicate a write and
                    // that writes will burst as long as CSn does not deassert. Same for reads.
                    if (~vif.we_n) begin
                        assert (!req.is_read()) else
                            `uvm_error(get_type_name(), "WEn asserted after OEn")
                        if (data_phase_countdown == -1) begin
                            int wr_delay = cs_cfg.wr_access_time - cs_cfg.we_on_time;
                            // Convert from FCLK period to CLK period
                            data_phase_countdown = wr_delay/(cs_cfg.gpmc_fclk_divider + 1);
                            `uvm_info(get_type_name(), $sformatf("CS %0d WE_n, delay %0d FCLKs (%0d CLKs)", cs_id, wr_delay, data_phase_countdown), UVM_DEBUG)
                            req.set_write();
                            req.set_address(addr);

                            if (cs_cfg.wait_write_monitoring) begin
                                wait_pin_id = cs_cfg.wait_pin_select;
                                wait_active = cfg.wait_pin_polarity[wait_pin_id];
                            end else begin
                                wait_pin_id = -1;
                            end
                        end
                    end // write command

                    // wait monitoring
                    if (wait_pin_id < 0 || vif.wait_[wait_pin_id] != wait_active) begin
                        if (data_phase_countdown == 0) begin
                            `uvm_info(get_type_name(), $sformatf("data beat CS %0d AD %0x", cs_id, vif.data_i), UVM_DEBUG)
                            payload.push_back(vif.data_i[7:0]);
                            byte_enable.push_back(vif.be0_n_cle);

                            if (cs_cfg.device_size == size_16_bit) begin
                                payload.push_back(vif.data_i[15:8]);
                                byte_enable.push_back(vif.be1_n);
                            end
                        end else if (data_phase_countdown > 0) begin
                            data_phase_countdown--;
                        end
                    end

                    @(posedge vif.clk, posedge vif.cs_n[cs_id]);
                end // CSn

                `uvm_info(get_type_name(), $sformatf("CS %0d deassert", cs_id), UVM_DEBUG)

                req.set_data_length(payload.size());
                req.set_byte_enable_length(byte_enable.size());
                begin
                    // Convert byte enable bit to byte width expected by uvm_tlm_gp
                    byte unsigned be[] = new[byte_enable.size()];
                    byte unsigned pd[] = new[payload.size()];
                    foreach(byte_enable[i])
                        be[i] = byte_enable[i] ? 8'hFF : 8'h00;
                    foreach(payload[i])
                        pd[i] = payload[i];
                    req.set_byte_enable(be);
                    req.set_data(pd);
                end
                if (cs_cfg.device_size == size_16_bit)
                    req.set_streaming_width(2);
                else
                    req.set_streaming_width(1);

                // There's really no other response indicates on GPMC apart from
                // a WAIT timeout, which isn't yet supported in this monitor.
                req.set_response_status(UVM_TLM_OK_RESPONSE);

                analysis_port[cs_id].write(req);
            end
        endtask
    endclass

endpackage
