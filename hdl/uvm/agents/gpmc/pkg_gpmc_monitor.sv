`include "uvm_macros.svh"

package pkg_gpmc_monitor;
    import uvm_pkg::*;
    import pkg_gpmc_config::*;

    class gpmc_monitor #(
        parameter ADDR_WIDTH=21,
        parameter DATA_WIDTH=16
    ) extends uvm_monitor;
        `uvm_component_utils(gpmc_monitor)

        gpmc_config cfg;
        virtual gpmc_if #(.ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH)) vif;

        // Separate analysis ports for each CS
        uvm_analysis_port#(uvm_tlm_generic_payload) analysis_port[7:0];

        function new(string name="gpmc_monitor", uvm_component parent = null);
            super.new(name, parent);
        endfunction

        virtual function void build_phase(uvm_phase phase);
            super.build_phase(phase);

            foreach (analysis_port[i])
                analysis_port[i] = new("analysis_port", this);

            if(!uvm_config_db#(virtual gpmc_config)::get(this, "", "gpmc_cfg", cfg))
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
                int cs_id = -1;
                bit [63:0] addr = 0;
                byte unsigned payload[$];
                bit byte_enable[$];
                int wait_pin_id = -1;
                bit wait_active = 1'b0;

                while (&vif.cs_n)
                    @(posedge vif.clk);

                foreach(vif.cs_n[i]) begin
                    if (~vif.cs_n[i]) begin
                        if (cs_id < 0)
                            cs_id = i;
                        else
                            `uvm_error(get_type_name(), $sformatf("CS %0d and %0d asserted simultaneously", cs_id, i))
                    end
                end

                while (~vif.cs_n[cs_id]) begin
                    int data_phase_countdown = -1;

                    if (~vif.adv_n_ale) begin
                        int bit_offset;
                        if (~vif.oe_n) begin
                            // first AAD phase. The documentation isn't super clear about how
                            // the full address is muxed onto the A and D lines. Let's assume
                            // the specified addr and data width is used for each phase.
                            if (cfg.cs_config[cs_id].mux_addr_data == no_mux) begin
                                bit_offset = ADDR_WIDTH;
                            end else begin
                                bit_offset = ADDR_WIDTH + DATA_WIDTH;
                            end
                        end else begin
                            // last AAD phase or first AD phase.
                            bit_offset = 0;
                        end

                        if (cfg.cs_config[cs_id].mux_addr_data == no_mux) begin
                            // If address/data are not muxed, load the address only from the
                            // address lines.
                            addr[bit_offset +: ADDR_WIDTH] = vif.addr[0 +: ADDR_WIDTH];
                        end else begin
                            // If muxed, load address from data and address lines.
                            addr[bit_offset +: DATA_WIDTH] = vif.data[0 +: DATA_WIDTH];
                            addr[bit_offset + DATA_WIDTH +: ADDR_WIDTH] = vif.addr[0 +: ADDR_WIDTH];
                        end
                    end else if (~vif.oe_n) begin
                        // if OEn asserts without ADVn, that indicates a read
                        // The GPMC read timing is specified relative to the start of CS. Compute
                        // the delay from OEn to a read.
                        assert (!req.is_write()) else
                            `uvm_error(get_type_name(), "OEn asserted after WEn")
                        if (data_phase_countdown == -1) begin
                            int rd_delay = cfg.cs_config[cs_id].rd_access_time - cfg.cs_config[cs_id].oe_on_time;
                            // Convert from FCLK period to CLK period
                            data_phase_countdown = rd_delay/(cfg.cs_config[cs_id].gpmc_fclk_divider + 1);
                            req.set_read();
                            req.set_address(addr);

                            if (cfg.cs_config[cs_id].wait_read_monitoring) begin
                                wait_pin_id = cfg.cs_config[cs_id].wait_pin_select;
                                wait_active = cfg.wait_pin_polarity[wait_pin_id];
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
                            int wr_delay = cfg.cs_config[cs_id].wr_access_time - cfg.cs_config[cs_id].we_on_time;
                            // Convert from FCLK period to CLK period
                            data_phase_countdown = wr_delay/(cfg.cs_config[cs_id].gpmc_fclk_divider + 1);
                            req.set_write();
                            req.set_address(addr);

                            if (cfg.cs_config[cs_id].wait_write_monitoring) begin
                                wait_pin_id = cfg.cs_config[cs_id].wait_pin_select;
                                wait_active = cfg.wait_pin_polarity[wait_pin_id];
                            end
                        end
                    end // write command

                    // wait monitoring
                    if (wait_pin_id < 0 || vif.wait_[wait_pin_id] != wait_active) begin
                        if (data_phase_countdown == 0) begin
                            payload.push_back(vif.data[7:0]);
                            byte_enable.push_back(vif.be0_n_cle);

                            if (cfg.cs_config[cs_id].device_size == size_16_bit) begin
                                payload.push_back(vif.data[15:8]);
                                byte_enable.push_back(vif.be1_n);
                            end
                        end else if (data_phase_countdown > 0) begin
                            data_phase_countdown--;
                        end
                    end
                end // CSn

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
                if (cfg.cs_config[cs_id].device_size == size_16_bit)
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
