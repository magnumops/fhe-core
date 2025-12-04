module butterfly (
    input  wire [63:0] u,
    input  wire [63:0] v,
    input  wire [63:0] w, // Twiddle factor
    input  wire [63:0] q,
    output wire [63:0] u_out,
    output wire [63:0] v_out
);
    // 1. Умножение V * W
    wire [63:0] vw;
    mod_mult mult_inst (
        .a(v), .b(w), .q(q), .out(vw)
    );

    // 2. Верхнее крыло: U + VW
    mod_add add_inst (
        .a(u), .b(vw), .q(q), .out(u_out)
    );

    // 3. Нижнее крыло: U - VW
    mod_sub sub_inst (
        .a(u), .b(vw), .q(q), .out(v_out)
    );
endmodule
