`include "uvm_macros.svh"

package pkg_vector_seq;
    import uvm_pkg::*;
    import pkg_vector_item::*;

    class vector_seq extends uvm_sequence;
        `uvm_object_utils(vector_seq)

        function new(string name="vector_seq");
            super.new(name);
        endfunction

        virtual task body();
            vector_item req = vector_item::type_id::create("req");
            for(int i=0; i < 20; i++) begin
                req.data = $urandom();
                `uvm_send(req)
            end
        endtask
    endclass //vector_seq extends uvm_sequence
    
endpackage