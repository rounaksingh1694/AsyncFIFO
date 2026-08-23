`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 06.08.2026 18:53:36
// Design Name: 
// Module Name: two_port_ram
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


module two_port_ram #(
    parameter DATA_WIDTH = 8,
    parameter ADDR_WIDTH = 3 // This should be PTR_WIDTH - 1
)(
//    input wire rst,
    // Write Domain
    input wire w_clk,
    input wire w_en,
    input wire [ADDR_WIDTH-1:0] w_addr,
    input wire [DATA_WIDTH-1:0] w_data,
    
    // Read Domain
    input wire r_clk,
    input wire r_en,
    input wire [ADDR_WIDTH-1:0] r_addr,
    output reg [DATA_WIDTH-1:0] r_data
    );
    
    reg [DATA_WIDTH - 1:0] fifo_mem [0:(2**ADDR_WIDTH)-1];
    
    always @(posedge w_clk) begin
//        if(rst) begin
//            fifo_mem[w_addr] <= 0;
//        end else 
        if(w_en) begin
            fifo_mem[w_addr] <= w_data;
        end
    end
    
    always @(posedge r_clk) begin
//        if(rst) begin
//            r_data <= 0;
//        end else 
        if(r_en) begin
            r_data <= fifo_mem[r_addr];
        end
    end
    
endmodule
