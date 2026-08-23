`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 23.08.2026 01:53:38
// Design Name: 
// Module Name: reset_synchroniser
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


module reset_synchroniser(
    input clk,
    input rst_async_in,
    output rst_sync_out
    );
    
    reg q1;
    reg q2;
    
    always @(posedge clk or posedge rst_async_in) begin
        if(rst_async_in) begin
            q1 <= 1'b1;
            q2 <= 1'b1;
        end else begin
            q1 <= rst_async_in;
            q2 <= q1;
        end
    end
    
    assign rst_sync_out = q2;
    
endmodule






