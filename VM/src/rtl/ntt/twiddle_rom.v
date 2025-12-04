module twiddle_rom (
    input  wire [11:0] addr, // Log2(4096) = 12 бит
    output reg  [63:0] data
);
    // ROM 4096 слов
    reg [63:0] mem [0:4095];

    initial begin
        $readmemh("twiddles_4k.hex", mem);
    end

    always @(*) begin
        data = mem[addr];
    end
endmodule
