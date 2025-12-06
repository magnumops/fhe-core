module ntt_engine #(
    parameter N_LOG = 12,
    parameter N     = 4096,
    parameter CORE_ID = 0
)(
    input  wire        clk,
    input  wire        rst,
    // Command Interface
    input  wire        cmd_valid,
    input  wire [7:0]  cmd_opcode,
    input  wire [3:0]  cmd_slot,
    input  wire [47:0] cmd_dma_addr,
    output reg         ready,
    
    // Config
    input  wire [63:0] q,
    input  wire [63:0] mu,
    input  wire [63:0] n_inv,

    // Arbiter Interface
    output reg         arb_req,
    output reg         arb_we,
    output reg [47:0]  arb_addr,
    output reg [63:0]  arb_wdata,
    input  wire        arb_gnt,
    input  wire        arb_valid,
    input  wire [63:0] arb_rdata,

    output wire [2:0]  dbg_state,
    output wire [63:0] perf_counter_out
);

    reg [63:0] mem [0:3][0:N-1];
    reg [63:0] w_mem [0:2*N-1];

    reg [1:0]  current_slot;
    reg        mode_intt;
    reg        agu_start;
    wire       agu_valid, agu_done;
    wire [N_LOG-1:0] agu_addr_u, agu_addr_v, agu_addr_w;

    // Performance Counters
    reg [63:0] perf_ntt_ops;
    assign perf_counter_out = perf_ntt_ops;

    // FSM States
    localparam S_IDLE       = 0;
    localparam S_DMA_READ_REQ = 1; 
    localparam S_DMA_READ_WAIT= 2; // Not strictly used in this ver but kept
    localparam S_DMA_WRITE  = 3;
    localparam S_CALC       = 4;

    reg [2:0] state;
    assign dbg_state = state;

    localparam [7:0] OPC_LOAD   = 8'h02;
    localparam [7:0] OPC_STORE  = 8'h03;
    localparam [7:0] OPC_LOAD_W = 8'h04;
    localparam [7:0] OPC_NTT    = 8'h10;
    localparam [7:0] OPC_INTT   = 8'h11;

    // DMA Counters
    reg [31:0] dma_req_idx; 
    reg [31:0] dma_ack_idx; 
    reg [31:0] dma_len;     

    ntt_control #(.N_LOG(N_LOG), .N(N)) u_control (
        .clk(clk), .rst(rst), .start(agu_start),
        .addr_u(agu_addr_u), .addr_v(agu_addr_v), .addr_w(agu_addr_w),
        .valid(agu_valid), .done(agu_done)
    );
    
    // Stub Math Logic
    wire [63:0] u_in = mem[current_slot][agu_addr_u];
    wire [63:0] v_in = mem[current_slot][agu_addr_v];
    // In real code, butterfly and mod_mult go here.
    // For this test, we just write back dummy values or keep state.
    // We assume data integrity is Phase 7 task. For Phase 6 we verify flow.

    always @(posedge clk) begin
        if (rst) perf_ntt_ops <= 0;
        else if (state == S_CALC && agu_valid) perf_ntt_ops <= perf_ntt_ops + 1;
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= S_IDLE;
            ready <= 1;
            agu_start <= 0;
            arb_req <= 0;
        end else begin
            // 1. Always capture data if it comes (valid is pulsed)
            if (arb_valid) begin
                 if (state == S_DMA_READ_REQ) begin
                    if (cmd_opcode == OPC_LOAD_W) w_mem[dma_ack_idx] <= arb_rdata;
                    else mem[current_slot][dma_ack_idx] <= arb_rdata;
                    dma_ack_idx <= dma_ack_idx + 1;
                 end
            end

            case (state)
                S_IDLE: begin
                    ready <= 1;
                    dma_req_idx <= 0;
                    dma_ack_idx <= 0;
                    if (cmd_valid) begin
                        ready <= 0;
                        current_slot <= cmd_slot[1:0];
                        case (cmd_opcode)
                            OPC_LOAD: begin
                                state <= S_DMA_READ_REQ;
                                dma_len <= N;
                                arb_addr <= cmd_dma_addr;
                            end
                            OPC_LOAD_W: begin
                                state <= S_DMA_READ_REQ;
                                dma_len <= 2*N;
                                arb_addr <= cmd_dma_addr;
                            end
                            OPC_NTT: begin
                                state <= S_CALC;
                                agu_start <= 1;
                            end
                            default: state <= S_IDLE;
                        endcase
                    end
                end
                
                S_DMA_READ_REQ: begin
                    // STRICT SEQUENTIAL FIX:
                    // Only send next request if we received the previous one (or if start)
                    // This prevents flooding the dumb arbiter.
                    if (dma_req_idx < dma_len && dma_req_idx == dma_ack_idx) begin
                        arb_req <= 1;
                        arb_we <= 0;
                        arb_addr <= cmd_dma_addr + (dma_req_idx * 8);
                        
                        if (arb_gnt) begin
                            dma_req_idx <= dma_req_idx + 1;
                            arb_req <= 0; // De-assert immediately to wait for ack
                        end
                    end else begin
                        arb_req <= 0;
                    end
                    
                    // Completion Check
                    if (dma_ack_idx >= dma_len) begin
                         state <= S_IDLE;
                    end
                end
                
                S_CALC: begin
                    agu_start <= 0;
                    if (agu_done) state <= S_IDLE;
                end
            endcase
        end
    end
endmodule
