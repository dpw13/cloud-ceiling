`include "uvm_macros.svh"

package pkg_vector_item;
    import uvm_pkg::*;

    class vector_item extends uvm_sequence_item;
        rand logic data;

        `uvm_object_utils_begin(vector_item)
            `uvm_field_int(data, UVM_DEFAULT)
        `uvm_object_utils_end

        virtual function string convert2str();
            return $sformatf("data: 0x%0x", data);
        endfunction

        function new(string name = "vector_item");
            super.new(name);
        endfunction
    endclass

endpackage