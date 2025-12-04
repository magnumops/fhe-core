module twiddle_rom (
    input  wire [2:0]  addr, // Log2(8) = 3 бита
    output reg  [63:0] data
);
    reg [63:0] mem [0:7];

    initial begin
        // $readmemh ищет файл относительно рабочей директории запуска симулятора
        $readmemh("twiddles.hex", mem);
    end

    always @(*) begin
        data = mem[addr];
    end
endmodule
