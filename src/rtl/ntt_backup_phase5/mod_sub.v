`timescale 1ns / 1ps
module mod_sub (
    input  wire [63:0] a,
    input  wire [63:0] b,
    input  wire [63:0] q,
    output wire [63:0] out
);
    // Расширяем для сравнения
    wire [64:0] a_ext = {1'b0, a};
    wire [64:0] b_ext = {1'b0, b};
    wire [64:0] q_ext = {1'b0, q};

    // Обычная разность
    wire [64:0] diff_direct = a_ext - b_ext;
    
    // Разность с займом у модуля (a + q - b)
    wire [64:0] diff_wrap = (a_ext + q_ext) - b_ext;

    // Если a >= b, используем прямую разность, иначе wrapped
    wire [64:0] res = (a_ext >= b_ext) ? diff_direct : diff_wrap;

    assign out = res[63:0];
endmodule
