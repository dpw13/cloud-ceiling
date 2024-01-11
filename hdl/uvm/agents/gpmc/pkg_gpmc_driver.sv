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
            // Set initial values. Use async assignment instead of using the clocking block
            vif.cs_n <= '1;
            // For whatever reason cs_n also needs the CB assignment or you get Xs on all CS lines.
            vif.driver_cb.cs_n <= '1;
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
            if (~vif.fclk)
                @(posedge vif.fclk);
            `uvm_info(get_type_name(), $sformatf("Register request %s using %s", req.convert2string(), cs_cfg.convert2string()), UVM_LOW)

            while (1) begin
                if (cycle == cs_cfg.cs_on_time)
                    vif.driver_cb.cs_n[cs_id] <= 1'b0;

                if (cs_cfg.mux_addr_data == aad_mux) begin
                    if (cycle == cs_cfg.adv_aad_mux_on_time) begin
                        bit [63:0] addr = req.get_address();
                        vif.driver_cb.adv_n_ale <= 1'b0;
                        vif.driver_cb.data <= addr[DATA_WIDTH+1 +: DATA_WIDTH];
                    end

                    if (cycle == cs_cfg.oe_aad_mux_on_time) begin
                        bit [63:0] addr = req.get_address();
                        vif.driver_cb.oe_n_re_n <= 1'b0;
                        vif.driver_cb.data <= addr[DATA_WIDTH+1 +: DATA_WIDTH];
                    end

                    if (cycle == cs_cfg.oe_aad_mux_off_time) begin
                        vif.driver_cb.oe_n_re_n <= 1'b1;
                        vif.driver_cb.data <= 'z;
                    end
                end

                if (cycle == cs_cfg.adv_on_time) begin
                    bit [63:0] addr = req.get_address();
                    vif.driver_cb.adv_n_ale <= 1'b0;
                    case (cs_cfg.mux_addr_data)
                        no_mux: begin
                            vif.addr <= addr[ADDR_WIDTH-1:0];
                        end
                        ad_mux: begin
                            // Assume 16-bit mode and start with addr[1]
                            vif.driver_cb.data <= addr[1 +: DATA_WIDTH];
                        end
                        aad_mux:
                            `uvm_warning(get_type_name(), "AAD mode not fully supported")
                    endcase
                end

                if (req.is_read()) begin
                    if (cycle == cs_cfg.cs_rd_off_time)
                        vif.driver_cb.cs_n[cs_id] <= 1'b1;

                    if (cycle == cs_cfg.adv_aad_mux_rd_off_time && cs_cfg.mux_addr_data == aad_mux) begin
                        vif.driver_cb.adv_n_ale <= 1'b1;
                        vif.driver_cb.oe_n_re_n <= 1'b1;
                        vif.driver_cb.data <= 'z;
                    end

                    if (cycle == cs_cfg.adv_rd_off_time) begin
                        vif.driver_cb.adv_n_ale <= 1'b1;
                        // Tristate data if address muxed onto data
                        if (cs_cfg.mux_addr_data != no_mux) begin
                            vif.driver_cb.data <= 'z;
                        end
                    end

                    if (cycle == cs_cfg.oe_on_time)
                        vif.driver_cb.oe_n_re_n <= 1'b0;
                    if (cycle == cs_cfg.oe_off_time) begin
                        vif.driver_cb.oe_n_re_n <= 1'b1;
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
                    int burst_count = req.get_data_length() / 2;
                    // wr_cycle_time already includes a single data beat
                    int burst_cycle_time = cs_cfg.wr_cycle_time + (burst_count - 1) * cs_cfg.page_burst_access_time;
                    int burst_cs_off = cs_cfg.cs_wr_off_time + (burst_count - 1) * cs_cfg.page_burst_access_time;
                    int burst_we_off = cs_cfg.we_off_time + (burst_count - 1) * cs_cfg.page_burst_access_time;
                    int burst_beat = (cycle - cs_cfg.wr_access_time) / cs_cfg.page_burst_access_time;

                    if (burst_beat < 0)
                        burst_beat = 0;
                    if (burst_beat > burst_count-1)
                        burst_beat = burst_count-1;

                    if (cycle == burst_cs_off)
                        vif.driver_cb.cs_n[cs_id] <= 1'b1;

                    if (cs_cfg.mux_addr_data == aad_mux) begin
                        if (cycle == cs_cfg.adv_aad_mux_wr_off_time) begin
                            // The spec is unclear on when the data lines tristate in AAD
                            // mode, so we tristate it at the first off time.
                            vif.driver_cb.adv_n_ale <= 1'b1;
                            vif.driver_cb.data <= 'z;
                        end
                    end

                    if (cycle == cs_cfg.adv_wr_off_time) begin
                        vif.driver_cb.adv_n_ale <= 1'b1;
                        // Tristate data if address muxed onto data
                        if (cs_cfg.mux_addr_data != no_mux)
                            vif.driver_cb.data <= 'z;
                    end

                    if (cycle == cs_cfg.we_on_time)
                        vif.driver_cb.we_n <= 1'b0;
                    if (cycle >= cs_cfg.wr_data_on_ad_mux_bus)
                        vif.driver_cb.data <= {req.m_data[2*burst_beat], req.m_data[2*burst_beat + 1]};
                    if (cycle >= burst_we_off) begin
                        vif.driver_cb.we_n <= 1'b1;
                        vif.driver_cb.data <= 'z;
                    end

                    // TODO: See SPRUH73Q Fig 7-22 and 7-23 for burst write timing diagrams

                    if (cycle == burst_cycle_time)
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
            vif.driver_cb.cs_n <= '1;
        endtask
    endclass

endpackage