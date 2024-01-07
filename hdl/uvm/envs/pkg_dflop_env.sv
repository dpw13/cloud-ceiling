`include "uvm_macros.svh"

package pkg_dflop_env;
    import uvm_pkg::*;
    import pkg_vector_agent::*;
    import pkg_vector_item::*;
    import pkg_generic_scoreboard::*;

    class dflop_env extends uvm_env;
        `uvm_component_utils(dflop_env)

        vector_agent m_d_vec_agent;
        vector_agent m_q_vec_agent;
        generic_scoreboard#(vector_item) m_scoreboard;

        function new(string name="dflop_env", uvm_component parent = null);
            super.new(name, parent);
        endfunction

        virtual function void build_phase(uvm_phase phase);
            super.build_phase(phase);

            m_d_vec_agent = vector_agent::type_id::create("m_d_vec_agent", this);
            m_q_vec_agent = vector_agent::type_id::create("m_q_vec_agent", this);
            m_scoreboard = generic_scoreboard#(vector_item)::type_id::create("m_scoreboard", this);
        endfunction

        virtual function void connect_phase(uvm_phase phase);
            m_d_vec_agent.m0.analysis_port.connect(m_scoreboard.ap_expected);
            m_q_vec_agent.m0.analysis_port.connect(m_scoreboard.ap_actual);
        endfunction
    endclass
endpackage