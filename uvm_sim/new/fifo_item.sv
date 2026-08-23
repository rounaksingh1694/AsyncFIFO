class fifo_item extends uvm_sequence_item;

    parameter int DATA_WIDTH = 8;

    rand bit [DATA_WIDTH-1:0] data;
    rand int unsigned delay_cycles;

    constraint c_delay {
        delay_cycles inside {[0:3]};
    }

    `uvm_object_utils_begin(fifo_item)
        `uvm_field_int(data, UVM_ALL_ON)
        `uvm_field_int(delay_cycles, UVM_ALL_ON)
    `uvm_object_utils_end

    function new(string name = "fifo_item");
        super.new(name);
    endfunction

endclass
