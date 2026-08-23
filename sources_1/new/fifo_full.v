`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 06.08.2026 18:10:24
// Design Name: 
// Module Name: fifo_full
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


module fifo_full #(parameter PTR_WIDTH = 4)(
    input wire [PTR_WIDTH-1:0] wptr_gray,
    input wire [PTR_WIDTH-1:0] sync_rptr_gray,
    output wire full
    );
    
    assign full = (wptr_gray == ({~sync_rptr_gray[PTR_WIDTH-1:PTR_WIDTH - 2], sync_rptr_gray[PTR_WIDTH - 3:0]}));
    
endmodule
