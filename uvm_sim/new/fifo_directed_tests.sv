//------------------------------------------------------------------------
// fifo_full_test
// Drives the write side past FIFO depth with no reads draining it, then
// checks that vif.full actually asserted. Closes the "full condition
// never verified" gap.
//------------------------------------------------------------------------
class fifo_full_test extends uvm_test;

    `uvm_component_utils(fifo_full_test)

    fifo_env env;

    function new(string name = "fifo_full_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        env = fifo_env::type_id::create("env", this);
    endfunction

    task run_phase(uvm_phase phase);
        fifo_write_full_sequence wseq;

        phase.raise_objection(this);

        wseq = fifo_write_full_sequence::type_id::create("wseq");
        wseq.start(env.write_agent.sequencer);

        // a few extra write-clock edges so the last attempted write and
        // the full flag settle before we sample it
        repeat (5) @(posedge env.write_agent.driver.vif.w_clk);

        if (!env.write_agent.driver.vif.full)
            `uvm_error("FULL_NOT_SET",
                "Expected FIFO full after writing past depth, but full=0")
        else
            `uvm_info("FULL_CHECK",
                "PASS: FIFO correctly asserted full after filling to depth",
                UVM_LOW)

        phase.drop_objection(this);
    endtask

endclass


//------------------------------------------------------------------------
// fifo_empty_test
// Drives read attempts with no writes ever happening, then checks that
// vif.empty stayed asserted throughout. Closes the "empty condition
// never verified" gap.
//------------------------------------------------------------------------
class fifo_empty_test extends uvm_test;

    `uvm_component_utils(fifo_empty_test)

    fifo_env env;

    function new(string name = "fifo_empty_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        env = fifo_env::type_id::create("env", this);
    endfunction

    task run_phase(uvm_phase phase);
        fifo_read_empty_sequence rseq;

        phase.raise_objection(this);

        rseq = fifo_read_empty_sequence::type_id::create("rseq");
        rseq.start(env.read_agent.sequencer);

        repeat (5) @(posedge env.read_agent.driver.vif.r_clk);

        if (!env.read_agent.driver.vif.empty)
            `uvm_error("EMPTY_NOT_SET",
                "Expected FIFO empty since no writes occurred, but empty=0")
        else
            `uvm_info("EMPTY_CHECK",
                "PASS: FIFO correctly stayed empty with no writes issued",
                UVM_LOW)

        phase.drop_objection(this);
    endtask

endclass


//------------------------------------------------------------------------
// fifo_wraparound_test
// Reuses the existing balanced write/read sequences but bumps num_items
// to several multiples of FIFO depth (8), forcing the write and read
// pointers to wrap around the pointer width multiple times while
// concurrent randomized-timing traffic is still running. The scoreboard
// (already wired into env) does the actual pass/fail check across every
// one of these transactions - if Gray-code wraparound logic has any bug,
// it shows up here as a mismatch or an underflow error.
//------------------------------------------------------------------------
class fifo_wraparound_test extends uvm_test;

    `uvm_component_utils(fifo_wraparound_test)

    fifo_env env;

    // depth is 8; 40 items = 5 full laps of the pointer, comfortably
    // beyond a single wrap so we're not just getting lucky on lap #1
    int unsigned num_items = 40;

    function new(string name = "fifo_wraparound_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        env = fifo_env::type_id::create("env", this);
    endfunction

    task run_phase(uvm_phase phase);
        fifo_write_sequence wseq;
        fifo_read_sequence  rseq;
        // separate local copy: inside a randomize() with {} block, a bare
        // "num_items" resolves to the object being randomized (wseq's or
        // rseq's own field), not this test's num_items, so we capture the
        // target count into its own variable first to avoid that collision
        int unsigned target_items;

        phase.raise_objection(this);

        target_items = num_items;

        wseq = fifo_write_sequence::type_id::create("wseq");
        rseq = fifo_read_sequence::type_id::create("rseq");

        if (!wseq.randomize() with { num_items == target_items; })
            `uvm_error("RANDFAIL", "fifo_write_sequence randomization failed")
        if (!rseq.randomize() with { num_items == target_items; })
            `uvm_error("RANDFAIL", "fifo_read_sequence randomization failed")

        fork
            wseq.start(env.write_agent.sequencer);
            rseq.start(env.read_agent.sequencer);
        join

        repeat (5) @(posedge env.read_agent.driver.vif.r_clk);

        phase.drop_objection(this);
    endtask

endclass
