`timescale 1ns / 1ps
module mem_arbiter(
    input wire clk, input wire rst,
    input wire req, input wire we,
    input wire [47:0] addr, input wire [63:0] wdata,
    output reg valid_dma, output reg [63:0] rdata_dma
);
    import "DPI-C" function longint read_ram(input longint addr);
    import "DPI-C" function void write_ram(input longint addr, input longint data);
    always @(posedge clk) begin
        valid_dma <= 0;
        if (!rst && req) begin
            if (we) write_ram({16'b0, addr}, wdata);
            else begin
                rdata_dma <= read_ram({16'b0, addr});
                valid_dma <= 1;
            end
        end
    end
endmodule
