`timescale 1ns / 1ps
module copy_engine(
    input clk,
    input [63:0] src_addr,
    input [63:0] dst_addr,
    input start,
    output reg done
);
    // ИСПРАВЛЕНИЕ: Увеличиваем буфер с 512 до 16384 слов (128 КБ).
    // Шифртекст весит ~88 КБ, теперь он поместится.
    bit [63:0] buffer [0:16383];

    import "DPI-C" function void dpi_read_burst(input longint addr, input int len, output bit [63:0] data []);
    import "DPI-C" function void dpi_write_burst(input longint addr, input int len, input bit [63:0] data []);

    reg [1:0] state = 0;

    always @(posedge clk) begin
        done <= 0;
        
        case (state)
            0: begin // IDLE
                if (start) state <= 1;
            end
            
            1: begin // READ
                // Читаем 16K слов (мгновенно в симуляции, блокирующе в C++)
                // Если файл меньше, mmap вернет нули, это безопасно.
                dpi_read_burst(src_addr, 16384, buffer);
                state <= 2;
            end
            
            2: begin // WRITE
                // Пишем все обратно
                dpi_write_burst(dst_addr, 16384, buffer);
                state <= 3;
            end
            
            3: begin // DONE
                done <= 1;
                state <= 0;
            end
        endcase
    end
endmodule
