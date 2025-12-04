module twiddle_rom (
    input  wire [11:0] addr, // 12 bit addr for 4096
    output reg  [63:0] data
);
    // 4096 слов по 64 бита
    reg [63:0] mem [0:4095];

    initial begin
        $readmemh("twiddles_4k.hex", mem);
    end

    always @(*) begin
        data = mem[addr];
    end
endmodule
