`timescale 1ns / 1ps
module dpi_mem_wrapper(
    input clk,
    input req,
    input we,
    input [63:0] addr,
    input [63:0] wdata,
    output reg valid,
    output reg [63:0] rdata
);
    import "DPI-C" function void dpi_write_ram(input longint addr, input longint val);
    import "DPI-C" function longint dpi_read_ram(input longint addr);

    always @(posedge clk) begin
        valid <= 0;
        if (req) begin
            if (we) begin
                dpi_write_ram(addr, wdata);
                // DO NOT assert valid for writes. 
                // This allows Burst Write to run at full speed (1 item/cycle)
                // without choking the Arbiter.
                valid <= 0; 
            end else begin
                rdata <= dpi_read_ram(addr);
                valid <= 1; // Read still needs valid to route data
            end
        end
    end
endmodule
