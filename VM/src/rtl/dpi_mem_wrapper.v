module dpi_mem_wrapper(
    input clk,
    input req,
    input we, // Write Enable (1=Write, 0=Read)
    input [63:0] addr,
    input [63:0] wdata,
    output reg [63:0] rdata,
    output reg valid // Data valid (ack)
);
    // DPI Imports
    import "DPI-C" function longint dpi_read_ram(input longint a);
    import "DPI-C" function void py_write_ram(input longint a, input longint d); 
    // Примечание: Для теста используем простые read/write (не burst), чтобы проще отладить арбитр.
    
    always @(posedge clk) begin
        valid <= 0;
        if (req) begin
            if (we) begin
                py_write_ram(addr, wdata);
                valid <= 1;
            end else begin
                rdata <= dpi_read_ram(addr);
                valid <= 1;
            end
        end
    end
endmodule
