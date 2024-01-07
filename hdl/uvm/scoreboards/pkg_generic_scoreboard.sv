`include "uvm_macros.svh"

package pkg_generic_scoreboard;
    import uvm_pkg::*;

    `uvm_analysis_imp_decl(_exp)
    `uvm_analysis_imp_decl(_act)

    class generic_scoreboard#(type T) extends uvm_scoreboard;
        `uvm_component_utils(generic_scoreboard#(T))

        function new(string name="generic_scoreboard", uvm_component parent = null);
            super.new(name, parent);
        endfunction

        uvm_analysis_imp_exp#(T, generic_scoreboard#(T)) ap_expected;
        uvm_analysis_imp_act#(T, generic_scoreboard#(T)) ap_actual;

        T exp[$];

        virtual function void build_phase(uvm_phase phase);
            super.build_phase(phase);

            ap_expected = new("ap_expected", this);
            ap_actual = new("ap_actual", this);
        endfunction

        virtual function void write_exp(T item);
            exp.push_back(item);
        endfunction

        virtual function void write_act(T item);
            T expected;
            
            if (exp.size() == 0) begin
                `uvm_error(get_type_name(), "Received actual before expected")
            end else begin
                expected = exp.pop_front();
                if (!expected.compare(item)) begin
                    `uvm_error(get_type_name(), $sformatf("Comparison mismatch: %s != %s", expected.convert2str(), item.convert2str()))
                end
            end
        endfunction

    endclass //vector_agent extends uvm_agent
endpackage