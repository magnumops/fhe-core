module dpi_mem_wrapper(
    input clk,
    input req,
    input we,
    input [63:0] addr,
    input [63:0] wdata,
    output reg valid,
    output reg [63:0] rdata
);
    // DPI Imports (using dpi_ prefix to match C++)
    import "DPI-C" function void dpi_write_ram(input longint addr, input longint val);
    import "DPI-C" function longint dpi_read_ram(input longint addr);

    always @(posedge clk) begin
        valid <= 0;
        if (req) begin
            if (we) begin
                dpi_write_ram(addr, wdata);
                // For write, valid usually acknowledges completion.
                // Depending on arbiter, it might expect valid for writes too.
                // Let's assert it.
                valid <= 1; 
            end else begin
                rdata <= dpi_read_ram(addr);
                valid <= 1;
            end
        end
    end
endmodule
