module logos_core #(
    parameter N_LOG = 12,
    parameter N     = 4096
)(
    input  wire        clk,
    input  wire        rst,
    // Context Params (Set via registers/wires for now)
    input  wire [63:0] ctx_q,
    input  wire [63:0] ctx_mu,
    input  wire [63:0] ctx_n_inv,
    // Status
    output wire        halted
);

    // Internal Signals
    wire        ntt_start;
    wire        ntt_mode;
    wire [55:0] ntt_addr;
    wire        ntt_done;

    // 1. Command Processor
    command_processor u_cpu (
        .clk(clk), .rst(rst),
        .ntt_start(ntt_start),
        .ntt_mode(ntt_mode),
        .ntt_addr(ntt_addr),
        .ntt_done(ntt_done),
        .halted(halted)
    );

    // 2. NTT Engine
    // Note: ntt_engine dma_addr is 64-bit, our payload is 56. Zero extend.
    ntt_engine #(.N_LOG(N_LOG), .N(N)) u_engine (
        .clk(clk), .rst(rst),
        .start(ntt_start),
        .mode(ntt_mode),
        .dma_addr({8'b0, ntt_addr}), 
        .q(ctx_q),
        .mu(ctx_mu),
        .n_inv(ctx_n_inv),
        .done(ntt_done)
    );

endmodule
