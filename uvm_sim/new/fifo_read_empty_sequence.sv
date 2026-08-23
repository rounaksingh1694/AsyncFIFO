class fifo_read_empty_sequence extends uvm_sequence #(fifo_item);

    `uvm_object_utils(fifo_read_empty_sequence)

    // No writes ever happen in the empty test, so every one of these
    // read attempts should be gated by the DUT's r_en && !empty logic,
    // and the read monitor's own !empty check should keep it out of
    // the scoreboard entirely.
    int unsigned num_items = 5;

    function new(string name = "fifo_read_empty_sequence");
        super.new(name);
    endfunction

    task body();
        fifo_item item;
        repeat (num_items) begin
            item = fifo_item::type_id::create("item");
            start_item(item);
            if (!item.randomize() with { delay_cycles == 0; })
                `uvm_error("RANDFAIL", "fifo_item randomization failed")
            finish_item(item);
        end
    endtask

endclass
