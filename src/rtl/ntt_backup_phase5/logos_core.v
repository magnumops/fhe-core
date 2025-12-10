`timescale 1ns / 1ps
module logos_core #(
    parameter N_LOG = 12,
    parameter N     = 4096
)(
    input  wire        clk,
    input  wire        rst,
    input  wire [63:0] ctx_q,
    input  wire [63:0] ctx_mu,
    input  wire [63:0] ctx_n_inv,
    output wire        halted,
    output wire [5:0]  dbg_engine_state,
    output wire [1:0]  dbg_cpu_state
);

    wire        cmd_valid_0;
    wire        cmd_valid_1;
    wire [7:0]  cmd_opcode;
    wire [3:0]  cmd_slot;
    wire [47:0] cmd_dma_addr;
    wire        engine_ready_0;
    wire        engine_ready_1;

    command_processor u_cpu (
        .clk(clk), .rst(rst),
        .cmd_valid_0(cmd_valid_0),
        .cmd_valid_1(cmd_valid_1),
        .cmd_opcode(cmd_opcode),
        .cmd_slot(cmd_slot),
        .cmd_dma_addr(cmd_dma_addr),
        .engine_ready_0(engine_ready_0),
        .engine_ready_1(engine_ready_1),
        .halted(halted),
        .dbg_state(dbg_cpu_state)
    );

    localparam MAX_DATA = 8192;
    
    // Core 0 Interface
    wire        c0_req, c0_rw, c0_ack;
    wire [47:0] c0_addr;
    wire [31:0] c0_len;
    bit [63:0]  c0_wdata [0:MAX_DATA-1];
    bit [63:0]  c0_rdata [0:MAX_DATA-1];
    wire [2:0]  state_0;

    // Core 1 Interface
    wire        c1_req, c1_rw, c1_ack;
    wire [47:0] c1_addr;
    wire [31:0] c1_len;
    bit [63:0]  c1_wdata [0:MAX_DATA-1];
    bit [63:0]  c1_rdata [0:MAX_DATA-1];
    wire [2:0]  state_1;

    mem_arbiter #(.N(N), .MAX_DATA(MAX_DATA)) u_arb (
        .clk(clk), .rst(rst),
        // Client 0
        .req_0(c0_req), .rw_0(c0_rw), .addr_0(c0_addr), .len_0(c0_len),
        .wdata_0(c0_wdata), .rdata_0(c0_rdata), .ack_0(c0_ack),
        // Client 1
        .req_1(c1_req), .rw_1(c1_rw), .addr_1(c1_addr), .len_1(c1_len),
        .wdata_1(c1_wdata), .rdata_1(c1_rdata), .ack_1(c1_ack)
    );

    // CORE 0
    ntt_engine #(.N_LOG(N_LOG), .N(N), .CORE_ID(0)) u_engine_0 (
        .clk(clk), .rst(rst),
        .cmd_valid(cmd_valid_0),
        .cmd_opcode(cmd_opcode),
        .cmd_slot(cmd_slot),
        .cmd_dma_addr(cmd_dma_addr),
        .ready(engine_ready_0),
        .q(ctx_q), .mu(ctx_mu), .n_inv(ctx_n_inv),
        .dbg_state(state_0),
        
        .arb_req(c0_req), .arb_rw(c0_rw), .arb_addr(c0_addr), .arb_len(c0_len),
        .arb_wdata(c0_wdata), .arb_rdata(c0_rdata), .arb_ack(c0_ack)
    );

    // CORE 1
    ntt_engine #(.N_LOG(N_LOG), .N(N), .CORE_ID(1)) u_engine_1 (
        .clk(clk), .rst(rst),
        .cmd_valid(cmd_valid_1),
        .cmd_opcode(cmd_opcode),
        .cmd_slot(cmd_slot),
        .cmd_dma_addr(cmd_dma_addr),
        .ready(engine_ready_1),
        .q(ctx_q), .mu(ctx_mu), .n_inv(ctx_n_inv),
        .dbg_state(state_1),
        
        .arb_req(c1_req), .arb_rw(c1_rw), .arb_addr(c1_addr), .arb_len(c1_len),
        .arb_wdata(c1_wdata), .arb_rdata(c1_rdata), .arb_ack(c1_ack)
    );

    assign dbg_engine_state = {state_1, state_0};

endmodule
