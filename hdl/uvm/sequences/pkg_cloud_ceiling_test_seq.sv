`include "uvm_macros.svh"

package pkg_cloud_ceiling_test_seq;
    import uvm_pkg::*;
    import pkg_cloud_ceiling_regmap::*;

    class cloud_ceiling_test_seq extends uvm_reg_sequence;
        `uvm_object_utils(cloud_ceiling_test_seq)

        function new(string name="cloud_ceiling_test_seq");
            super.new(name);
        endfunction

        virtual task body();
            cloud_ceiling_regmap regmodel;
            uvm_status_e status;
            int rdata, tmp;

            if (!uvm_config_db#(cloud_ceiling_regmap)::get(null, "uvm_test_top", "m_regmodel", regmodel))
                `uvm_fatal(get_type_name(), "Could not get register model")

            regmodel.ID_REG.read(status, rdata);
            assert (status == UVM_IS_OK);
            assert (rdata == 32'hC10D);

            tmp = $urandom() & 16'hFFFF;
            regmodel.SCRATCH_REG.write(status, tmp);
            assert (status == UVM_IS_OK);
            regmodel.SCRATCH_REG.read(status, rdata);
            assert (status == UVM_IS_OK);
            assert (tmp == rdata);
        endtask
    endclass //cloud_ceiling_test_seq extends uvm_sequence
    
endpackage