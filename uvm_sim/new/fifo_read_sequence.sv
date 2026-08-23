class fifo_read_sequence extends uvm_sequence #(fifo_item);

    `uvm_object_utils(fifo_read_sequence)

    rand int unsigned num_items;

    constraint c_num_items {
        num_items inside {[10:20]};
    }

    function new(string name = "fifo_read_sequence");
        super.new(name);
    endfunction

    task body();
        fifo_item item;
        repeat (num_items) begin
            item = fifo_item::type_id::create("item");
            start_item(item);
            if (!item.randomize())
                `uvm_error("RANDFAIL", "fifo_item randomization failed")
            finish_item(item);
        end
    endtask

endclass
