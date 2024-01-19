`include "uvm_macros.svh"

package pkg_led_top_test;
    import uvm_pkg::*;
    import pkg_gpmc_config::*;

    // Environment
    import pkg_led_top_env::*;

    // Sequence
    import pkg_cloud_ceiling_test_seq::*;

    class led_top_test extends uvm_test;

        `uvm_component_utils(led_top_test)

        led_top_env m_env;

        gpmc_config #(.ADDR_WIDTH(21)) m_gpmc_cfg;

        function new(string name="led_top_test", uvm_component parent = null);
            super.new(name, parent);
        endfunction

        virtual function void build_phase(uvm_phase phase);
            super.build_phase(phase);

            m_env = led_top_env::type_id::create("m_env", this);

            if (!uvm_config_db#(gpmc_config#(.ADDR_WIDTH(21)))::get(null, "", "gpmc_cfg", m_gpmc_cfg))
                `uvm_fatal(get_type_name(), "Unable to get GPMC if")

            uvm_config_db#(gpmc_config#(.ADDR_WIDTH(21)))::set(this, "m_env.m_gpmc_agent.*", "gpmc_cfg", m_gpmc_cfg);
        endfunction

        virtual task reset_phase(uvm_phase phase);
            super.main_phase(phase);

            phase.raise_objection(this);
            // Yes, I know this should be a sequence...
            #1100ns;
            phase.drop_objection(this);
        endtask

        virtual task main_phase(uvm_phase phase);
            cloud_ceiling_test_seq seq = cloud_ceiling_test_seq::type_id::create("seq");

            super.main_phase(phase);

            phase.raise_objection(this);
            seq.start(m_env.m_gpmc_agent.s0);
            phase.drop_objection(this);
        endtask

        virtual function void end_of_elaboration_phase(uvm_phase phase);
            uvm_top.print_topology();
            uvm_top.set_report_verbosity_level_hier(UVM_MEDIUM);
        endfunction

    endclass
endpackage