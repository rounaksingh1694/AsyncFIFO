`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 06.08.2026 17:59:54
// Design Name: 
// Module Name: fifo_empty
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


module fifo_empty #(parameter PTR_WIDTH = 4)(
    input wire [PTR_WIDTH-1:0] rptr_gray,
    input wire [PTR_WIDTH-1:0] sync_wptr_gray,
    output empty
    );
    
    assign empty = rptr_gray == sync_wptr_gray;
    
endmodule
