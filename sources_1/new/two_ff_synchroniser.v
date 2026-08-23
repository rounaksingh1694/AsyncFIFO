`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 06.08.2026 17:45:36
// Design Name: 
// Module Name: two_ff_synchroniser
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


module two_ff_synchroniser #(parameter PTR_WIDTH = 4)(
    input clk,
    input rst,
    input wire [PTR_WIDTH - 1:0] async_in,
    output wire [PTR_WIDTH - 1:0] sync_out
    );
    
    reg [PTR_WIDTH - 1:0] q1;
    reg [PTR_WIDTH - 1:0] q2;
    
    always @(posedge clk or posedge rst) begin
        if(rst) begin
            q1 <= {PTR_WIDTH{1'b0}};
            q2 <= {PTR_WIDTH{1'b0}};
        end else begin
            q1 <= async_in;
            q2 <= q1;
        end
    end
    
    assign sync_out = q2;
    
endmodule
