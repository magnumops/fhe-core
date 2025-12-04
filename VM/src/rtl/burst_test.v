module burst_test(
    input clk,
    input [63:0] start_addr,
    output reg [63:0] data_0,
    output reg [63:0] data_9
);
    // ИСПРАВЛЕНИЕ: Используем bit (2-state logic), чтобы совместиться с C++ uint64_t
    bit [63:0] buffer [0:9];

    // В импорте тоже указываем bit
    import "DPI-C" function void dpi_read_burst(input longint addr, input int len, output bit [63:0] data []);

    always @(posedge clk) begin
        // Читаем
        dpi_read_burst(start_addr, 10, buffer);
        
        // Перекладываем в выходные порты (они могут остаться reg)
        data_0 <= buffer[0];
        data_9 <= buffer[9];
    end

endmodule
