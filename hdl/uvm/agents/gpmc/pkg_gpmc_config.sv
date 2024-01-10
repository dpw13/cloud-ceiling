`include "uvm_macros.svh"

package pkg_gpmc_config;
    import uvm_pkg::*;

    typedef enum bit[0:0] {
        async = 0,
        sync = 1
    } sync_type_t;

    typedef enum bit[1:0] {
        len_4_words = 0,
        len_8_words = 1,
        len_16_words = 2
    } page_len_t;

    typedef enum bit[1:0] {
        size_8_bit = 0,
        size_16_bit = 1
    } device_size_t;

    typedef enum bit[1:0] {
        nor_type = 0,
        nand_type = 2
    } device_type_t;

    typedef enum bit[1:0] {
        no_mux = 0,
        aad_mux = 1,
        ad_mux = 2
    } mux_type_t;

    typedef enum bit[1:0] {
        div_1x = 0,
        div_2x = 1,
        div_3x = 2,
        div_4x = 3
    } fclk_divider_t;

    class gpmc_cs_config extends uvm_object;
        `uvm_object_utils_begin(gpmc_cs_config)
        `uvm_object_utils_end

        // CONFIG1
        bit wrap_burst = 0;
        bit read_multiple = 0;
        sync_type_t read_type = async; // 1 for synchronous, 0 for asynchronous
        bit write_multiple = 0;
        sync_type_t write_type = async; // 1 for synchronous, 0 for asynchronous
        bit [1:0] clk_activation_time = 0;
        page_len_t attached_device_page_length = len_4_words;
        bit wait_read_monitoring = 0;
        bit wait_write_monitoring = 0;
        bit [1:0] wait_monitoring_time = 0;
        bit [1:0] wait_pin_select = 0;
        device_size_t device_size = size_8_bit;
        device_type_t device_type = nor_type;
        mux_type_t mux_addr_data = no_mux;
        bit time_paragranularity = 0;
        fclk_divider_t gpmc_fclk_divider = div_1x;

        // CONFIG2
        bit [4:0] cs_wr_off_time = 0;
        bit [4:0] cs_rd_off_time = 0;
        bit cs_extra_delay = 0;
        bit [3:0] cs_on_time = 0;

        // CONFIG3
        bit [2:0] adv_aad_mux_wr_off_time = 0;
        bit [2:0] adv_aad_mux_rd_off_time = 0;
        bit [4:0] adv_wr_off_time = 0;
        bit [4:0] adv_rd_off_time = 0;
        bit adv_extra_delay = 0;
        bit [2:0] adv_aad_mux_on_time = 0;
        bit [3:0] adv_on_time = 0;

        // CONFIG4
        bit [4:0] we_off_time = 0;
        bit we_extra_delay = 0;
        bit [3:0] we_on_time = 0;
        bit [2:0] oe_aad_mux_off_time = 0;
        bit [4:0] oe_off_time = 0;
        bit oe_extra_delay = 0;
        bit [2:0] oe_aad_mux_on_time = 0;
        bit [3:0] oe_on_time = 0;

        // CONFIG5
        bit [3:0] page_burst_access_time = 0;
        bit [4:0] rd_access_time = 0;
        bit [4:0] wr_cycle_time = 0;
        bit [4:0] rd_cycle_time = 0;

        // CONFIG6
        bit [4:0] wr_access_time = 0; // used only to gate WAIT signal
        bit [3:0] wr_data_on_ad_mux_bus = 0;
        bit [3:0] cycle_2_cycle_delay = 0;
        bit cycle_2_cycle_same_cs_en = 0;
        bit cycle_2_cycle_diff_cs_en = 0;
        bit [3:0] bus_turnaround = 0;

        // CONFIG7
        bit [4:0] mask_address = 0;
        bit cs_valid = 0;
        bit [5:0] base_address = 0;

        function new(string name="gpmc_cs_config");
            super.new(name);
        endfunction //new()

        virtual function int window_size();
            bit [5:0] size = ~{1'b1, mask_address} + 1;
            return size;
        endfunction

        virtual function string convert2string();
            if (cs_valid) begin
                return $sformatf("GPMC CS at %0x:%0x", {base_address, 24'h0}, {base_address + window_size(), 24'h0});
            end else begin
                return "GPMC CS disabled";
            end
        endfunction

        virtual function void set_range(bit [63:0] base, bit [63:0] size);
            assert (base[63:30] == 0) else
                $fatal("GPMC window base too high");
            assert (base[23:0] == 0) else
                $fatal("GPMC window base must be aligned to 16 MB");
            
            assert (size[63:29] == 0) else
                $fatal("GPMC window must be less than 256 MB");
            assert (size[23:0] == 0) else
                $fatal("GPMC window size must be aligned to 16 MB");
            assert ($countones(size) == 1) else
                $fatal("GPMC window size must be power of 2");

            base_address = base[29:24];
            mask_address = ~(size[28:24] - 1);
            cs_valid = 1'b1;
        endfunction

        virtual function bit in_range(bit [63:0] addr);
            // Build the address mask. The address will be ANDed with this mask and compared
            // to the base offset.
            bit [63:0] addr_mask = {35'h7FFFFFFFF, mask_address, 24'h000000};
            // Calculate the base offset as a byte-aligned address
            bit [63:0] base_addr = {34'h0, base_address, 24'h000000};

            if (cs_valid) begin
                `uvm_info(get_type_name(), $sformatf("in_range(%0x) mask = %0x base = %0x", addr, addr_mask, base_addr), UVM_DEBUG)
                return (cs_valid && (addr & addr_mask) == base_addr);
            end else begin
                return 1'b0;
            end
        endfunction
    endclass

    class gpmc_config #(
        parameter ADDR_WIDTH = 16,
        parameter DATA_WIDTH = 16,
        parameter CS_COUNT = 8
    ) extends uvm_object;
        `uvm_object_param_utils_begin(gpmc_config#(.ADDR_WIDTH(ADDR_WIDTH)))
        `uvm_object_utils_end

        // SYSCONFIG
        bit auto_idle = 0;

        // TIMEOUT_CONTROL
        bit [8:0] timeout_start_value = 0;
        bit timeout_enable = 0;

        // CONFIG
        bit [1:0] wait_pin_polarity = 0;
        bit write_protect = 0;
        bit nand_force_posted_write = 0;

        // CS configs (unpacked)
        gpmc_cs_config cs_config [7:0];

        // interface
        virtual gpmc_if #(.ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH)) vif;

        function new(string name="gpmc_config");
            super.new(name);
            foreach (cs_config[i])
                cs_config[i] = gpmc_cs_config::type_id::create($sformatf("cs_config[%0d]", i));
        endfunction //new()
    endclass //gpmc_config extends uvm_object
endpackage