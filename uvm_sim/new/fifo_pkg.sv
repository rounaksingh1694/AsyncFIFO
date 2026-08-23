`ifndef FIFO_PKG_SV
`define FIFO_PKG_SV

package fifo_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"

    // fifo_if.sv is compiled separately, before this package, and is
    // referenced by classes here only as "virtual fifo_if" - interfaces
    // are not SystemVerilog classes, so they don't get included inside
    // a package the way item/driver/monitor/etc. do.

    `include "fifo_item.sv"
    `include "fifo_sequencer.sv"
    `include "fifo_write_driver.sv"
    `include "fifo_read_driver.sv"
    `include "fifo_write_sequence.sv"
    `include "fifo_read_sequence.sv"
    `include "fifo_write_full_sequence.sv"
    `include "fifo_read_empty_sequence.sv"
    `include "fifo_write_monitor.sv"
    `include "fifo_read_monitor.sv"
    `include "fifo_write_agent.sv"
    `include "fifo_read_agent.sv"
    `include "fifo_scoreboard.sv"
    `include "fifo_env.sv"
    `include "fifo_test.sv"
    `include "fifo_directed_tests.sv"

endpackage

`endif