module mod_add (
    input  wire [63:0] a,
    input  wire [63:0] b,
    input  wire [63:0] q,
    output wire [63:0] out
);
    // Расширяем до 65 бит, чтобы не потерять переполнение при a+b
    wire [64:0] sum = {1'b0, a} + {1'b0, b};
    
    // Подготовка q для сравнения (тоже 65 бит)
    wire [64:0] q_ext = {1'b0, q};
    
    // Вычисляем разность на случай, если sum >= q
    wire [64:0] diff = sum - q_ext;
    
    // Выбираем результат. Обе ветки тернарного оператора теперь строго 65 бит.
    wire [64:0] res_full = (sum >= q_ext) ? diff : sum;
    
    // Явно обрезаем до 64 бит для выхода
    assign out = res_full[63:0];
endmodule
