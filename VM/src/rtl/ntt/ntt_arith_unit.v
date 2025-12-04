module ntt_arith_unit (
    input  wire        clk,
    input  wire        rst,
    input  wire [2:0]  opcode, // Расширили до 3 бит: 0=ADD, 1=MULT, 2=SUB, 3=BF
    input  wire [63:0] op_a,   // U for Butterfly
    input  wire [63:0] op_b,   // V for Butterfly
    input  wire [63:0] op_w,   // W (Twiddle) for Butterfly
    input  wire [63:0] op_q,
    output reg  [63:0] res_out_1, // Result (or U_out)
    output reg  [63:0] res_out_2  // V_out (only for Butterfly)
);
    wire [63:0] sum_res;
    wire [63:0] mult_res;
    wire [63:0] sub_res;
    wire [63:0] bf_u, bf_v;

    mod_add u_adder (.a(op_a), .b(op_b), .q(op_q), .out(sum_res));
    mod_mult u_mult (.a(op_a), .b(op_b), .q(op_q), .out(mult_res));
    mod_sub u_sub   (.a(op_a), .b(op_b), .q(op_q), .out(sub_res));
    
    // Внимание: для бабочки входы мапятся иначе: a->u, b->v, w->w
    butterfly u_bf  (.u(op_a), .v(op_b), .w(op_w), .q(op_q), .u_out(bf_u), .v_out(bf_v));

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            res_out_1 <= 0;
            res_out_2 <= 0;
        end else begin
            case (opcode)
                3'b000: begin res_out_1 <= sum_res;  res_out_2 <= 0; end
                3'b001: begin res_out_1 <= mult_res; res_out_2 <= 0; end
                3'b010: begin res_out_1 <= sub_res;  res_out_2 <= 0; end
                3'b011: begin res_out_1 <= bf_u;     res_out_2 <= bf_v; end
                default: begin res_out_1 <= 64'hDEAD; res_out_2 <= 64'hBEEF; end
            endcase
        end
    end
endmodule
