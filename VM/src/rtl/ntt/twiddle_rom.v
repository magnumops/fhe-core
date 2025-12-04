module twiddle_rom (
    input  wire [12:0] addr, // 13 bit addr (Bit 12 selects Fwd/Inv)
    output reg  [63:0] data
);
    // 8192 слова
    reg [63:0] mem [0:8191];

    initial begin
        $readmemh("twiddles_combined.hex", mem);
    end

    always @(*) begin
        data = mem[addr];
    end
endmodule
