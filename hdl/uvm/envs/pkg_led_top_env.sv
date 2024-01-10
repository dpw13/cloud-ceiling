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