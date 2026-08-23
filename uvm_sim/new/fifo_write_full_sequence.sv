class fifo_write_full_sequence extends uvm_sequence #(fifo_item);

    `uvm_object_utils(fifo_write_full_sequence)

    // FIFO depth = 2^(PTR_WIDTH-1) = 8 for PTR_WIDTH=4.
    // num_items is deliberately > depth so the burst continues attempting
    // writes after the FIFO is already full, exercising the full-gating
    // logic in both the RTL (w_en && !full) and the write monitor
    // (which mirrors that same gate before reporting to the scoreboard).
    int unsigned num_items = 12;

    function new(string name = "fifo_write_full_sequence");
        super.new(name);
    endfunction

    task body();
        fifo_item item;
        repeat (num_items) begin
            item = fifo_item::type_id::create("item");
            start_item(item);
            // delay_cycles forced to 0: back-to-back writes with no gaps,
            // so the driver never gives the read side a chance to drain
            // anything in between (read agent isn't even started in the
            // full test, but forcing 0 delay here keeps this sequence
            // reusable/deterministic on its own).
            if (!item.randomize() with { delay_cycles == 0; })
                `uvm_error("RANDFAIL", "fifo_item randomization failed")
            finish_item(item);
        end
    endtask

endclass
