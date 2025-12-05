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

    // --- ARBITER & SIGNALS ---
    localparam MAX_DATA = 8192;
    
    // Core 0 Signals
    wire        c0_req, c0_rw, c0_ack;
    wire [47:0] c0_addr;
    wire [31:0] c0_len;
    bit [63:0]  c0_wdata [0:MAX_DATA-1];
    bit [63:0]  c0_rdata [0:MAX_DATA-1];

    // Core 1 Signals (Grounded for now)
    wire        c1_req = 0;
    wire        c1_rw = 0;
    wire [47:0] c1_addr = 0;
    wire [31:0] c1_len = 0;
    bit [63:0]  c1_wdata [0:MAX_DATA-1];
    wire [63:0] c1_rdata [0:MAX_DATA-1]; // Unused output
    wire        c1_ack;

    mem_arbiter #(.N(N), .MAX_DATA(MAX_DATA)) u_arb (
        .clk(clk), .rst(rst),
        // Client 0
        .req_0(c0_req), .rw_0(c0_rw), .addr_0(c0_addr), .len_0(c0_len),
        .wdata_0(c0_wdata), .rdata_0(c0_rdata), .ack_0(c0_ack),
        // Client 1
        .req_1(c1_req), .rw_1(c1_rw), .addr_1(c1_addr), .len_1(c1_len),
        .wdata_1(c1_wdata), .rdata_1(c1_rdata), .ack_1(c1_ack)
    );

    ntt_engine #(.N_LOG(N_LOG), .N(N)) u_engine (
        .clk(clk), .rst(rst),
        .cmd_valid(cmd_valid),
        .cmd_opcode(cmd_opcode),
        .cmd_slot(cmd_slot),
        .cmd_dma_addr(cmd_dma_addr),
        .ready(engine_ready),
        .q(ctx_q), .mu(ctx_mu), .n_inv(ctx_n_inv),
        .dbg_state(dbg_engine_state),
        
        // Connect to Arbiter
        .arb_req(c0_req),
        .arb_rw(c0_rw),
        .arb_addr(c0_addr),
        .arb_len(c0_len),
        .arb_wdata(c0_wdata),
        .arb_rdata(c0_rdata),
        .arb_ack(c0_ack)
    );

endmodule
