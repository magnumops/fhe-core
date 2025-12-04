module ntt_arith_unit (
    input  wire        clk,
    input  wire        rst,
    input  wire [2:0]  opcode, // 0=ADD, 1=MULT, 2=SUB, 3=BF, 4=ROM
    input  wire [63:0] op_a,   // Operand A (or ROM Addr)
    input  wire [63:0] op_b,
    input  wire [63:0] op_w,
    input  wire [63:0] op_q,
    output reg  [63:0] res_out_1,
    output reg  [63:0] res_out_2
);
    wire [63:0] sum_res, mult_res, sub_res;
    wire [63:0] bf_u, bf_v;
    wire [63:0] rom_data;

    mod_add u_adder (.a(op_a), .b(op_b), .q(op_q), .out(sum_res));
    mod_mult u_mult (.a(op_a), .b(op_b), .q(op_q), .out(mult_res));
    mod_sub u_sub   (.a(op_a), .b(op_b), .q(op_q), .out(sub_res));
    butterfly u_bf  (.u(op_a), .v(op_b), .w(op_w), .q(op_q), .u_out(bf_u), .v_out(bf_v));
    
    // ROM Instance. Берем адрес из op_a (младшие 3 бита)
    twiddle_rom u_rom (.addr(op_a[2:0]), .data(rom_data));

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            res_out_1 <= 0; res_out_2 <= 0;
        end else begin
            case (opcode)
                3'b000: begin res_out_1 <= sum_res;  res_out_2 <= 0; end
                3'b001: begin res_out_1 <= mult_res; res_out_2 <= 0; end
                3'b010: begin res_out_1 <= sub_res;  res_out_2 <= 0; end
                3'b011: begin res_out_1 <= bf_u;     res_out_2 <= bf_v; end
                3'b100: begin res_out_1 <= rom_data; res_out_2 <= 0; end // NEW: ROM Read
                default: begin res_out_1 <= 64'hDEAD; res_out_2 <= 64'hBEEF; end
            endcase
        end
    end
endmodule
