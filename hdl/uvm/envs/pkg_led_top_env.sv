`include "uvm_macros.svh"

package pkg_led_top_env;
    import uvm_pkg::*;
    import pkg_gpmc_agent::*;
    import pkg_generic_scoreboard::*;
    import pkg_cloud_ceiling_regmap::*;

    class led_top_env extends uvm_env;
        `uvm_component_utils(led_top_env)

        gpmc_agent #(.DATA_WIDTH(16)) m_gpmc_agent;
        generic_scoreboard#(uvm_tlm_gp) m_scoreboard;
        cloud_ceiling_regmap m_regmodel;
        uvm_reg_tlm_adapter m_adapter;
        uvm_reg_predictor#(uvm_tlm_gp) m_predictor;

        function new(string name="led_top_env", uvm_component parent = null);
            super.new(name, parent);
        endfunction

        virtual function void build_phase(uvm_phase phase);
            super.build_phase(phase);

            m_gpmc_agent = gpmc_agent#(.DATA_WIDTH(16))::type_id::create("m_gpmc_agent", this);
            m_scoreboard = generic_scoreboard#(uvm_tlm_gp)::type_id::create("m_scoreboard", this);

            if (m_regmodel == null) begin
                m_regmodel = new;
                m_adapter = uvm_reg_tlm_adapter::type_id::create("m_adapter", this);
                m_predictor = uvm_reg_predictor#(uvm_tlm_gp)::type_id::create("m_predictor", this);

                m_regmodel.build();
                /*
                 * Override the generated map's bus width to 2 bytes instead of 32 (the maximum
                 * burst width). This is a hack that allows the reg adapter to issue full-length
                 * bursts to the FIFO while ensuring that 32-bit accesses get split into multiple
                 * 16-bit accesses.
                 *
                 * Why don't the accesses to the REGS window automatically get split? Because
                 * uvm_reg_map::get_physical_addresses_to_map queries the parent map and uses
                 * its bus width, even if the submap is narrower.
                 *
                 * An alternative implementation would be to create multiple regmaps and bind them
                 * together here, but this hack essentially does the same thing while still using
                 * most of what peakrdl produces for us.
                 *
                 * So why doesn't this result in the FIFO_MEM burst_write getting chopped up into
                 * 2-byte accesses? I still don't know and at this point don't care. The UVM reg
                 * and memory implementations leave a lot to be desired.
                 */
                m_regmodel.default_map.configure(m_regmodel, 0, 2, UVM_LITTLE_ENDIAN);
                m_regmodel.lock_model();

                uvm_config_db#(cloud_ceiling_regmap)::set(null, "uvm_test_top", "m_regmodel", m_regmodel);
            end

        endfunction

        virtual function void connect_phase(uvm_phase phase);
            m_predictor.map = m_regmodel.default_map;
            m_predictor.adapter = m_adapter;
            m_regmodel.default_map.set_sequencer(m_gpmc_agent.s0, m_adapter);

            m_gpmc_agent.m0.analysis_port[1].connect(m_predictor.bus_in);
            m_gpmc_agent.m0.analysis_port[1].connect(m_scoreboard.ap_expected);
        endfunction
    endclass
endpackage