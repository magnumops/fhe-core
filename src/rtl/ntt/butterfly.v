`timescale 1ns / 1ps
module butterfly (
    input  wire [63:0] u,
    input  wire [63:0] v,
    input  wire [63:0] w,
    input  wire [63:0] q,
    input  wire [63:0] mu, // NEW
    output wire [63:0] u_out,
    output wire [63:0] v_out
);
    wire [63:0] vw;
    // Pass MU to multiplier
    mod_mult mult_inst (.a(v), .b(w), .q(q), .mu(mu), .out(vw));

    mod_add add_inst (.a(u), .b(vw), .q(q), .out(u_out));
    mod_sub sub_inst (.a(u), .b(vw), .q(q), .out(v_out));
endmodule
