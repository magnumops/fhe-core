module ntt_arith_unit (
    input  wire        clk,
    input  wire        rst,
    input  wire [1:0]  opcode, // 0=ADD, 1=MULT
    input  wire [63:0] op_a,
    input  wire [63:0] op_b,
    input  wire [63:0] op_q,
    output reg  [63:0] res_out
);
    wire [63:0] sum_res;
    wire [63:0] mult_res;

    mod_add u_adder (
        .a(op_a), .b(op_b), .q(op_q), .out(sum_res)
    );

    mod_mult u_mult (
        .a(op_a), .b(op_b), .q(op_q), .out(mult_res)
    );

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            res_out <= 0;
        end else begin
            case (opcode)
                2'b00: res_out <= sum_res;
                2'b01: res_out <= mult_res;
                default: res_out <= 64'hDEADBEEF;
            endcase
        end
    end
endmodule
