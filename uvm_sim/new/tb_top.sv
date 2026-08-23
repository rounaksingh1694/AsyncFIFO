`timescale 1ns / 1ps

import uvm_pkg::*;
`include "uvm_macros.svh"
import fifo_pkg::*;

module tb_top;

    bit w_clk;
    bit r_clk;

    always #5  w_clk = ~w_clk;
    always #20 r_clk = ~r_clk;

    fifo_if #(.DATA_WIDTH(8)) vif (
        .w_clk(w_clk),
        .r_clk(r_clk)
    );

    top_module #(
        .DATA_WIDTH(8),
        .PTR_WIDTH(4)
    ) dut (
        .rst(vif.rst),

        .w_clk(vif.w_clk),
        .w_en(vif.w_en),
        .w_data(vif.w_data),
        .full(vif.full),

        .r_clk(vif.r_clk),
        .r_en(vif.r_en),
        .r_data(vif.r_data),
        .empty(vif.empty)
    );

    initial begin
        uvm_config_db#(virtual fifo_if)::set(null, "*", "vif", vif);
        // no hardcoded test class here anymore - pass +UVM_TESTNAME=<test>
        // on the xsim/simulation command line to select which test runs.
        // Defaults to fifo_test if no plusarg is given.
        run_test();
    end

endmodule