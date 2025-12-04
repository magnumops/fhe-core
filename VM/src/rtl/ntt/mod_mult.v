module mod_mult (
    input  wire [63:0] a,
    input  wire [63:0] b,
    input  wire [63:0] q,
    output wire [63:0] out
);
    // Умножение 64x64 -> 128 бит
    wire [127:0] prod = {64'b0, a} * {64'b0, b};
    
    // Деление по модулю 128 бит
    wire [127:0] rem = prod % {64'b0, q};
    
    // Явное приведение к 64 битам
    assign out = rem[63:0];
endmodule
