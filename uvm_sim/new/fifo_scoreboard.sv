`uvm_analysis_imp_decl(_write)
`uvm_analysis_imp_decl(_read)

class fifo_scoreboard extends uvm_scoreboard;

    `uvm_component_utils(fifo_scoreboard)

    uvm_analysis_imp_write #(fifo_item, fifo_scoreboard) write_imp;
    uvm_analysis_imp_read  #(fifo_item, fifo_scoreboard) read_imp;

    fifo_item expected_q[$];

    int unsigned match_count;
    int unsigned mismatch_count;

    function new(string name = "fifo_scoreboard", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        write_imp = new("write_imp", this);
        read_imp  = new("read_imp", this);
    endfunction

    function void write_write(fifo_item item);
        expected_q.push_back(item);
    endfunction

    function void write_read(fifo_item item);
        fifo_item exp_item;
        if (expected_q.size() == 0) begin
            `uvm_error("SBUNDERFLOW", "read observed but reference queue is empty")
            mismatch_count++;
            return;
        end
        exp_item = expected_q.pop_front();
        if (exp_item.data !== item.data) begin
            `uvm_error("SBMISMATCH",
                $sformatf("data mismatch: expected %0h, got %0h", exp_item.data, item.data))
            mismatch_count++;
        end else begin
            match_count++;
        end
    endfunction

    function void report_phase(uvm_phase phase);
        `uvm_info("SBREPORT",
            $sformatf("matches=%0d mismatches=%0d leftover_in_queue=%0d",
                match_count, mismatch_count, expected_q.size()), UVM_LOW)
    endfunction

endclass
