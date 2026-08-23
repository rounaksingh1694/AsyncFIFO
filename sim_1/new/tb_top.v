`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 06.08.2026 20:08:09
// Design Name: 
// Module Name: tb_top
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


module tb_top();

    parameter DATA_WIDTH = 8;
    parameter PTR_WIDTH = 4;
    
    integer i;
    
    // Inputs
    reg w_clk;
    reg r_clk;
    reg rst;
    reg w_en;
    reg r_en;
    reg [DATA_WIDTH-1:0] w_data;
    
    // Outputs
    wire full;
    wire empty;
    wire [DATA_WIDTH-1:0] r_data;
    
    top_module #(
        .DATA_WIDTH(DATA_WIDTH),
        .PTR_WIDTH(PTR_WIDTH)
    ) DUT (
        .rst(rst),
        // Wite
        .w_clk(w_clk),
        .w_en(w_en),
        .w_data(w_data),
        .full(full),
        // Read
        .r_clk(r_clk),
        .r_en(r_en),
        .r_data(r_data),
        .empty(empty)
    );
    
    // Write Clock -> f = 100MHz
    always #5 w_clk = ~w_clk;
    // Read Clock -> f = 25MHz
    always #20 r_clk = ~r_clk;
    
    task write_fifo;
        input [DATA_WIDTH-1:0] data_in;
        begin
            @(negedge w_clk);
            if (!full) begin
                w_en = 1;
                w_data = data_in;
                @(negedge w_clk);
                w_en = 0;
            end else begin
                $display("[$time] WARNING: Tried to write %h but FIFO is FULL!", data_in);
            end
        end
    endtask
    
    task read_fifo;
        begin
            @(negedge r_clk);
            if (!empty) begin
                r_en = 1;
                @(negedge r_clk);
                r_en = 0;
            end else begin
                $display("[$time] WARNING: Tried to read but FIFO is EMPTY!");
            end
        end
    endtask
    
    initial begin
        // all inputs to 0 
        w_clk = 0;
        r_clk = 0;
        w_en = 0;
        r_en = 0;
        w_data = 0;
        rst = 0;

        // Apply Reset
        #10 rst = 1; 
        #50 rst = 0; 
        #50;
        
        $display("--- Starting Write Burst ---");
        for (i = 1; i <= 10; i = i + 1) begin
            write_fifo(i); // Writes 1, 2, 3, 4, 5, 6, 7, 8
        end
        
        #100;

        $display("--- Starting Read Burst ---");
        for (i = 1; i <= 10; i = i + 1) begin
            read_fifo();
        end

        #100;
        
        $display("--- Simultaneous Read/Write Test ---");
        fork
            begin
                for (i = 8'hAA; i <= 8'hAF; i = i + 1) begin
                    write_fifo(i);
                    #20;
                end
            end
            
            
            begin
                #40;
                for (i = 0; i < 6; i = i + 1) begin
                    read_fifo();
                end
            end
        join

        #20;
        $display("--- Simulation Complete ---");
        $finish;
    end

endmodule
