`timescale 1ns / 1ps
module dma_unit(
    input clk, input rst,
    input start,
    input [63:0] base_addr,
    output reg busy,
    
    // Mem Port
    output reg mem_req, output reg mem_we, output reg [63:0] mem_addr, output reg [63:0] mem_wdata,
    input mem_gnt
);
    reg [3:0] counter;
    
    always @(posedge clk) begin
        if (rst) begin
            busy <= 0; mem_req <= 0; counter <= 0;
        end else begin
            if (start && !busy) begin
                busy <= 1;
                counter <= 0;
            end
            
            if (busy) begin
                mem_req <= 1; 
                mem_we <= 1;
                mem_addr <= base_addr + (counter * 8);
                mem_wdata <= 64'hDEAD0000 + counter;
                
                if (mem_gnt) begin
                    // Transaction accepted
                    counter <= counter + 1;
                    if (counter == 9) begin // Write 10 words
                        busy <= 0;
                        mem_req <= 0;
                    end
                end
            end
        end
    end
endmodule
