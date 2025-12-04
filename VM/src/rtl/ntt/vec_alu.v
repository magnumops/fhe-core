module vec_alu (
    input  wire [2:0]  opcode, // 0=ADD, 1=SUB, 2=MULT
    input  wire [63:0] op_a,
    input  wire [63:0] op_b,
    input  wire [63:0] q,
    output reg  [63:0] res_out
);
    wire [63:0] sum_res, sub_res, mult_res;

    // Instantiation of modular arithmetic units
    // Note: mod_mult now uses Barrett Reduction (Day 1 achievement)
    mod_add u_adder (.a(op_a), .b(op_b), .q(q), .out(sum_res));
    mod_sub u_sub   (.a(op_a), .b(op_b), .q(q), .out(sub_res));
    mod_mult u_mult (.a(op_a), .b(op_b), .q(q), .out(mult_res));

    // Result MUX
    always @(*) begin
        case (opcode)
            3'b000: res_out = sum_res;  // VEC_ADD
            3'b001: res_out = sub_res;  // VEC_SUB
            3'b010: res_out = mult_res; // VEC_MULT
            default: res_out = 64'd0;
        endcase
    end
endmodule
