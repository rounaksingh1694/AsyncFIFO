`timescale 1ns / 1ps

interface fifo_if #(parameter DATA_WIDTH = 8) (
    input bit w_clk,
    input bit r_clk
    );

    logic rst;

    logic w_en;
    logic [DATA_WIDTH-1:0] w_data;
    logic full;

    logic r_en;
    logic [DATA_WIDTH-1:0] r_data;
    logic empty;

    clocking wcb @(posedge w_clk);
        output w_en;
        output w_data;
        input  full;
    endclocking

    clocking rcb @(posedge r_clk);
        output r_en;
        input  r_data;
        input  empty;
    endclocking

    clocking wmcb @(posedge w_clk);
        input w_en;
        input w_data;
        input full;
    endclocking

    clocking rmcb @(posedge r_clk);
        input r_en;
        input r_data;
        input empty;
    endclocking

endinterface