`include "uvm_macros.svh"

package pkg_dflop_test;
    import uvm_pkg::*;

    // Environment
    import pkg_dflop_env::*;

    // Sequence
    import pkg_vector_seq::*;

    class dflop_test extends uvm_test;

        `uvm_component_utils(dflop_test)

        dflop_env m_env;

        virtual vector_if m_d_vif;
        virtual vector_if m_q_vif;

        function new(string name="dflop_test", uvm_component parent = null);
            super.new(name, parent);
        endfunction

        virtual function void build_phase(uvm_phase phase);
            super.build_phase(phase);

            m_env = dflop_env::type_id::create("m_env", this);

            if (!uvm_config_db#(virtual vector_if)::get(null, "", "d_vif", m_d_vif))
                `uvm_fatal(get_type_name(), "Unable to get D vector if")
            if (!uvm_config_db#(virtual vector_if)::get(null, "", "q_vif", m_q_vif))
                `uvm_fatal(get_type_name(), "Unable to get Q vector if")

            uvm_config_db#(virtual vector_if)::set(this, "m_env.m_d_vec_agent.*", "vif", m_d_vif);
            uvm_config_db#(virtual vector_if)::set(this, "m_env.m_q_vec_agent.*", "vif", m_q_vif);
        endfunction

        virtual task run_phase(uvm_phase phase);
            vector_seq seq = vector_seq::type_id::create("seq");

            super.run_phase(phase);

            phase.raise_objection(this);
            seq.start(m_env.m_d_vec_agent.s0);
            phase.drop_objection(this);
        endtask

        virtual function void end_of_elaboration_phase(uvm_phase phase);
            uvm_top.print_topology();
        endfunction

    endclass
endpackage