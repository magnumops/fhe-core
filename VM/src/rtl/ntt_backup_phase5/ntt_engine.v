`timescale 1ns / 1ps
module ntt_engine #(
    parameter N_LOG = 12,
    parameter N     = 4096,
    parameter CORE_ID = 0
)(
    input  wire        clk,
    input  wire        rst,
    input  wire        cmd_valid,
    input  wire [7:0]  cmd_opcode,
    input  wire [3:0]  cmd_slot,      
    input  wire [47:0] cmd_dma_addr,  
    output reg         ready,
    input  wire [63:0] q,
    input  wire [63:0] mu,
    input  wire [63:0] n_inv,
    
    output reg         arb_req,
    output reg         arb_rw,       
    output reg [47:0]  arb_addr,
    output reg [31:0]  arb_len,
    output bit [63:0]  arb_wdata [0:2*N-1], // Driven sequentially
    input  bit [63:0]  arb_rdata [0:2*N-1],
    input  wire        arb_ack,

    output wire [2:0]  dbg_state
);

    bit [63:0] mem [0:3][0:N-1];
    bit [63:0] w_mem [0:2*N-1];

    reg [1:0] current_slot; 
    reg [1:0] source_slot;  
    reg       mode_intt;
    reg       agu_start;
    wire      agu_valid, agu_done;
    wire [N_LOG-1:0] agu_addr_u, agu_addr_v, agu_addr_w;

    reg [63:0] perf_total_cycles = 0;
    reg [63:0] perf_active_cycles = 0;
    reg [63:0] perf_ntt_ops = 0;
    reg [63:0] perf_alu_ops = 0;
    
    reg inc_ntt_pulse;
    reg inc_alu_pulse;

    localparam S_IDLE      = 0;
    localparam S_DMA_READ  = 1;
    localparam S_DMA_WRITE = 2;
    localparam S_LOAD_W    = 3;
    localparam S_CALC      = 4; 
    localparam S_SCALE     = 5;
    localparam S_ALU       = 6; 
    localparam S_PERF_DUMP = 7; 

    reg [2:0] state;
    assign dbg_state = state;

    localparam [7:0] OPC_LOAD   = 8'h02;
    localparam [7:0] OPC_STORE  = 8'h03;
    localparam [7:0] OPC_LOAD_W = 8'h04;
    localparam [7:0] OPC_READ_PERF = 8'h0F;
    localparam [7:0] OPC_NTT    = 8'h10;
    localparam [7:0] OPC_INTT   = 8'h11;
    localparam [7:0] OPC_ADD    = 8'h20;
    localparam [7:0] OPC_SUB    = 8'h21;
    localparam [7:0] OPC_MULT   = 8'h22;

    ntt_control #(.N_LOG(N_LOG), .N(N)) u_control (
        .clk(clk), .rst(rst), .start(agu_start),
        .addr_u(agu_addr_u), .addr_v(agu_addr_v), .addr_w(agu_addr_w),
        .valid(agu_valid), .done(agu_done)
    );

    wire [N_LOG:0] w_addr = {mode_intt, agu_addr_w};
    wire [63:0] w_data = w_mem[w_addr];
    wire [63:0] u_in = mem[current_slot][agu_addr_u];
    wire [63:0] v_in = mem[current_slot][agu_addr_v];
    wire [63:0] u_out, v_out;

    butterfly u_bf (
        .u(u_in), .v(v_in), .w(w_data), .q(q), .mu(mu), .u_out(u_out), .v_out(v_out)
    );

    reg [N_LOG:0] scale_idx;
    wire [63:0] scale_in = mem[current_slot][scale_idx[N_LOG-1:0]];
    wire [63:0] scale_out;
    mod_mult u_scaler (
        .a(scale_in), .b(n_inv), .q(q), .mu(mu), .out(scale_out)
    );

    reg [N_LOG:0] alu_idx;
    reg [2:0]     alu_opcode_reg; 
    wire [63:0]   alu_op_a = mem[current_slot][alu_idx[N_LOG-1:0]];
    wire [63:0]   alu_op_b = mem[source_slot][alu_idx[N_LOG-1:0]];
    wire [63:0]   alu_res;

    vec_alu u_vec_alu (
        .opcode(alu_opcode_reg),
        .op_a(alu_op_a), .op_b(alu_op_b), .q(q), .mu(mu), .res_out(alu_res)
    );

    // Perf Counters Logic (Persistent)
    always @(posedge clk) begin
        perf_total_cycles <= perf_total_cycles + 1;
        if (state != S_IDLE) perf_active_cycles <= perf_active_cycles + 1;
        if (inc_ntt_pulse) perf_ntt_ops <= perf_ntt_ops + 1;
        if (inc_alu_pulse) perf_alu_ops <= perf_alu_ops + 1;
    end

    // Main FSM
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= S_IDLE;
            ready <= 1;
            agu_start <= 0;
            current_slot <= 0;
            alu_idx <= 0;
            inc_ntt_pulse <= 0;
            inc_alu_pulse <= 0;
            arb_req <= 0;
        end else begin
            inc_ntt_pulse <= 0;
            inc_alu_pulse <= 0;

            case (state)
                S_IDLE: begin
                    ready <= 1;
                    if (cmd_valid) begin
                        $display("[CORE %0d] CMD: %h", CORE_ID, cmd_opcode);
                        ready <= 0;
                        current_slot <= cmd_slot[1:0];
                        source_slot  <= cmd_dma_addr[47:46];

                        case (cmd_opcode)
                            OPC_LOAD: begin
                                state <= S_DMA_READ;
                                arb_addr <= cmd_dma_addr;
                                arb_len <= N;
                                arb_rw <= 0; 
                                arb_req <= 1;
                            end
                            OPC_STORE: begin
                                state <= S_DMA_WRITE;
                                arb_addr <= cmd_dma_addr;
                                arb_len <= N;
                                arb_rw <= 1; 
                                // Blocking loop for array copy in FSM
                                for(int k=0; k<N; k++) arb_wdata[k] = mem[cmd_slot[1:0]][k];
                                arb_req <= 1;
                            end
                            OPC_LOAD_W: begin
                                state <= S_LOAD_W;
                                arb_addr <= cmd_dma_addr;
                                arb_len <= 2*N; 
                                arb_rw <= 0; 
                                arb_req <= 1;
                            end
                            OPC_READ_PERF: begin
                                state <= S_PERF_DUMP;
                                arb_addr <= cmd_dma_addr;
                                arb_len <= 4;
                                arb_rw <= 1; 
                                // SYNCHRONOUS DRIVE (FIXED)
                                arb_wdata[0] = perf_total_cycles;
                                arb_wdata[1] = perf_active_cycles;
                                arb_wdata[2] = perf_ntt_ops;
                                arb_wdata[3] = perf_alu_ops;
                                arb_req <= 1;
                                $display("[CORE %0d] DUMP: Cyc=%d", CORE_ID, perf_total_cycles);
                            end
                            OPC_NTT: begin
                                mode_intt <= 0;
                                state <= S_CALC;
                                agu_start <= 1;
                                inc_ntt_pulse <= 1;
                            end
                            OPC_INTT: begin
                                mode_intt <= 1;
                                state <= S_CALC;
                                agu_start <= 1;
                                inc_ntt_pulse <= 1;
                            end
                            OPC_ADD: begin
                                alu_opcode_reg <= 3'b000;
                                state <= S_ALU;
                                alu_idx <= 0;
                                inc_alu_pulse <= 1;
                            end
                            OPC_SUB: begin
                                alu_opcode_reg <= 3'b001;
                                state <= S_ALU;
                                alu_idx <= 0;
                                inc_alu_pulse <= 1;
                            end
                            OPC_MULT: begin
                                alu_opcode_reg <= 3'b010;
                                state <= S_ALU;
                                alu_idx <= 0;
                                inc_alu_pulse <= 1;
                            end
                            default: state <= S_IDLE;
                        endcase
                    end
                end

                S_DMA_READ: begin
                    if (arb_ack) begin
                        arb_req <= 0;
                        for(int i=0; i<N; i++) mem[current_slot][i] = arb_rdata[i];
                        state <= S_IDLE;
                    end
                end

                S_DMA_WRITE: begin
                    if (arb_ack) begin
                        arb_req <= 0;
                        state <= S_IDLE;
                    end
                end

                S_LOAD_W: begin
                    if (arb_ack) begin
                        arb_req <= 0;
                        for(int i=0; i<2*N; i++) w_mem[i] = arb_rdata[i];
                        state <= S_IDLE;
                    end
                end
                
                S_PERF_DUMP: begin
                    if (arb_ack) begin
                        arb_req <= 0;
                        state <= S_IDLE;
                    end
                end
                
                S_CALC: begin
                    agu_start <= 0;
                    if (agu_valid) begin
                        mem[current_slot][agu_addr_u] <= u_out;
                        mem[current_slot][agu_addr_v] <= v_out;
                    end
                    if (agu_done) begin
                        if (mode_intt == 1) begin
                            state <= S_SCALE;
                            scale_idx <= 0;
                        end else begin
                            state <= S_IDLE;
                        end
                    end
                end

                S_SCALE: begin
                    if (scale_idx < N) begin
                        mem[current_slot][scale_idx[N_LOG-1:0]] <= scale_out;
                        scale_idx <= scale_idx + 1;
                    end else begin
                        state <= S_IDLE;
                    end
                end

                S_ALU: begin
                    if (alu_idx < N) begin
                        mem[current_slot][alu_idx[N_LOG-1:0]] <= alu_res;
                        alu_idx <= alu_idx + 1;
                    end else begin
                        state <= S_IDLE;
                    end
                end
            endcase
        end
    end
endmodule
