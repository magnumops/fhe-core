`timescale 1ns / 1ps
module mem_test(
    input clk,
    input [63:0] addr,      // 64-битный адрес
    output reg [63:0] data  // 64-битные данные
);
    // Импорт функции из C++
    // pure function означает, что она не имеет побочных эффектов внутри Verilog (не ждет времени)
    import "DPI-C" function longint dpi_read_ram(input longint a);

    always @(posedge clk) begin
        // Вызываем C++ функцию как родную
        data <= dpi_read_ram(addr);
    end

endmodule
