class fifo_test extends uvm_test;

    `uvm_component_utils(fifo_test)

    fifo_env env;

    function new(string name = "fifo_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        env = fifo_env::type_id::create("env", this);
    endfunction

    task run_phase(uvm_phase phase);
        fifo_write_sequence wseq;
        fifo_read_sequence  rseq;

        phase.raise_objection(this);

        wseq = fifo_write_sequence::type_id::create("wseq");
        rseq = fifo_read_sequence::type_id::create("rseq");

        // num_items is a rand field - it defaults to 0 until randomized,
        // which would silently generate zero transactions if skipped.
        if (!wseq.randomize())
            `uvm_error("RANDFAIL", "fifo_write_sequence randomization failed")
        if (!rseq.randomize())
            `uvm_error("RANDFAIL", "fifo_read_sequence randomization failed")

        fork
            wseq.start(env.write_agent.sequencer);
            rseq.start(env.read_agent.sequencer);
        join

        // drain time: the last read's r_data is a registered output that
        // becomes valid one r_clk edge after item_done() already fired,
        // so the monitor needs a few extra cycles to report it to the
        // scoreboard before the test ends
        repeat (5) @(posedge env.read_agent.driver.vif.r_clk);

        phase.drop_objection(this);
    endtask

endclass
