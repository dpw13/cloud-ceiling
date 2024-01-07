`include "uvm_macros.svh"

package pkg_led_top_env;
    import uvm_pkg::*;
    import pkg_gpmc_agent::*;
    import pkg_generic_scoreboard::*;

    class led_top_env extends uvm_env;
        `uvm_component_utils(led_top_env)

        gpmc_agent #(.DATA_WIDTH(16)) m_gpmc_agent;
        generic_scoreboard#(uvm_tlm_gp) m_scoreboard;

        function new(string name="led_top_env", uvm_component parent = null);
            super.new(name, parent);
        endfunction

        virtual function void build_phase(uvm_phase phase);
            super.build_phase(phase);

            m_gpmc_agent = gpmc_agent#(.DATA_WIDTH(16))::type_id::create("m_gpmc_agent", this);
            m_scoreboard = generic_scoreboard#(uvm_tlm_gp)::type_id::create("m_scoreboard", this);
        endfunction

        virtual function void connect_phase(uvm_phase phase);
            m_gpmc_agent.m0.analysis_port[1].connect(m_scoreboard.ap_expected);
        endfunction
    endclass
endpackage