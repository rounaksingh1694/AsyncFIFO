`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 06.08.2026 15:50:02
// Design Name: 
// Module Name: b2g_converter
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


module binary_to_gray #(parameter PTR_WIDTH = 4)(
    input wire [PTR_WIDTH - 1: 0] binary,
    output wire [PTR_WIDTH - 1:0] gray
    );
    
    assign gray = binary ^ (binary >> 1);
    
endmodule
