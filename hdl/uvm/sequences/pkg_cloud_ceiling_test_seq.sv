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
            byte unsigned burst_bytes[127:0];
            uvm_reg_data_t burst_data[];

            if (!uvm_config_db#(cloud_ceiling_regmap)::get(null, "uvm_test_top", "m_regmodel", regmodel))
                `uvm_fatal(get_type_name(), "Could not get register model")

            regmodel.REGS.ID_REG.read(status, rdata);
            assert (status == UVM_IS_OK);
            assert (rdata == 32'hC10D);

            tmp = $urandom() & 16'hFFFF;
            regmodel.REGS.SCRATCH_REG.write(status, tmp);
            assert (status == UVM_IS_OK);
            regmodel.REGS.SCRATCH_REG.read(status, rdata);
            assert (status == UVM_IS_OK);
            assert (tmp == rdata);

            foreach (burst_bytes[i]) begin
                burst_bytes[i] = $urandom();
            end
            burst_data = new[8*$size(burst_bytes)/$bits(uvm_reg_data_t)];
            foreach (burst_bytes[i]) begin
                int word = 8*i/$bits(uvm_reg_data_t);
                int offset = 8*i - word*$bits(uvm_reg_data_t);
                burst_data[word][offset +: 8] = burst_bytes[i];
            end

            regmodel.FIFO_MEM.m_mem.burst_write(status, 0, burst_data);
            assert (status == UVM_IS_OK);

            #400ns;
        endtask
    endclass //cloud_ceiling_test_seq extends uvm_sequence
    
endpackage