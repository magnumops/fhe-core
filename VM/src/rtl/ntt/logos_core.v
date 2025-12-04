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
    // DEBUG PORTS
    output wire [2:0]  dbg_engine_state,
    output wire [1:0]  dbg_cpu_state
);

    wire        cmd_valid;
    wire [7:0]  cmd_opcode;
    wire [3:0]  cmd_slot;
    wire [47:0] cmd_dma_addr;
    wire        engine_ready;

    command_processor u_cpu (
        .clk(clk), .rst(rst),
        .cmd_valid(cmd_valid),
        .cmd_opcode(cmd_opcode),
        .cmd_slot(cmd_slot),
        .cmd_dma_addr(cmd_dma_addr),
        .engine_ready(engine_ready),
        .halted(halted),
        .dbg_state(dbg_cpu_state)
    );

    ntt_engine #(.N_LOG(N_LOG), .N(N)) u_engine (
        .clk(clk), .rst(rst),
        .cmd_valid(cmd_valid),
        .cmd_opcode(cmd_opcode),
        .cmd_slot(cmd_slot),
        .cmd_dma_addr(cmd_dma_addr),
        .ready(engine_ready),
        .q(ctx_q),
        .mu(ctx_mu),
        .n_inv(ctx_n_inv),
        .dbg_state(dbg_engine_state)
    );

endmodule
