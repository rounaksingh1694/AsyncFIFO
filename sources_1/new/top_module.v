`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 06.08.2026 19:09:51
// Design Name: 
// Module Name: top_module
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module top_module #(
    parameter DATA_WIDTH = 8,
    parameter PTR_WIDTH = 4
)(
    input wire rst, 
    // Write Domain
    input wire w_clk,
    input wire w_en,
    input wire [DATA_WIDTH-1:0] w_data,
    output wire full,
    
    // Read Domain
    input wire r_clk,
    input wire r_en,
    output wire [DATA_WIDTH-1:0] r_data,
    output wire empty
    );
    
    reg  [PTR_WIDTH-1:0] wptr_bin;
    reg  [PTR_WIDTH-1:0] rptr_bin;
    
    wire [PTR_WIDTH-1:0] wptr_gray;
    wire [PTR_WIDTH-1:0] rptr_gray;
    
    wire [PTR_WIDTH-1:0] sync_wptr_gray;
    wire [PTR_WIDTH-1:0] sync_rptr_gray;
    
    wire w_rst_sync, r_rst_sync;
    
    reset_synchroniser rst_sync_w (
        .clk(w_clk),
        .rst_async_in(rst),
        .rst_sync_out(w_rst_sync)
    );
    
    reset_synchroniser rst_sync_r (
        .clk(r_clk),
        .rst_async_in(rst),
        .rst_sync_out(r_rst_sync)
    );
    
    always @(posedge w_clk or posedge w_rst_sync) begin
        if(w_rst_sync) begin
            wptr_bin <= {PTR_WIDTH{1'b0}};
        end else if(w_en && !full) begin
            wptr_bin <= wptr_bin + 1'b1;
        end
    end
    
    always @(posedge r_clk or posedge r_rst_sync) begin
        if(r_rst_sync) begin
            rptr_bin <= {PTR_WIDTH{1'b0}};
        end else if(r_en && !empty) begin
            rptr_bin <= rptr_bin + 1'b1;
        end
    end
    
    binary_to_gray #(.PTR_WIDTH(PTR_WIDTH)) b2g_write (
        .binary(wptr_bin),
        .gray(wptr_gray)
    );
    
    binary_to_gray #(.PTR_WIDTH(PTR_WIDTH)) b2g_read (
        .binary(rptr_bin),
        .gray(rptr_gray)
    );
    
    two_ff_synchroniser #(.PTR_WIDTH(PTR_WIDTH)) sync_w2r (
        .clk(r_clk),
        .rst(r_rst_sync),
        .async_in(wptr_gray),
        .sync_out(sync_wptr_gray)
    );
    
    two_ff_synchroniser #(.PTR_WIDTH(PTR_WIDTH)) sync_r2w (
        .clk(w_clk),
        .rst(w_rst_sync),
        .async_in(rptr_gray),
        .sync_out(sync_rptr_gray)
    );
    
    fifo_full #(.PTR_WIDTH(PTR_WIDTH)) full_flag (
        .wptr_gray(wptr_gray),
        .sync_rptr_gray(sync_rptr_gray),
        .full(full)
    );
    
    fifo_empty #(.PTR_WIDTH(PTR_WIDTH)) empty_flag (
        .rptr_gray(rptr_gray),
        .sync_wptr_gray(sync_wptr_gray),
        .empty(empty)
    );
    
    two_port_ram #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(PTR_WIDTH - 1)
    ) fifo_mem (
//        .rst(rst),
    
        .w_clk(w_clk),
        .w_en(w_en && !full),
        .w_addr(wptr_bin[PTR_WIDTH-2 : 0]),
        .w_data(w_data),

        .r_clk(r_clk),
        .r_en(r_en && !empty),
        .r_addr(rptr_bin[PTR_WIDTH-2 : 0]),
        .r_data(r_data)
    );
    
endmodule
