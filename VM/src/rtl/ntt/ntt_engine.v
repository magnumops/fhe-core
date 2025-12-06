`timescale 1ns / 1ps

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
    output wire        ready,          // Now a wire (logic)

    // Arbiter Interface
    output reg         arb_req,
    output reg         arb_we,
    output reg [47:0]  arb_addr,
    output wire [63:0] arb_wdata,
    input  wire        arb_gnt,
    input  wire        arb_valid,
    input  wire [63:0] arb_rdata,

    // Debug & Metrics
    output reg [3:0]   dbg_state,      // Outputs DMA state for now
    output reg [63:0]  perf_counter_out
);

    // --- STATES ---
    // Common IDLE
    localparam S_IDLE       = 4'd0;
    
    // DMA States
    localparam S_DMA_READ   = 4'd1;
    localparam S_DMA_WRITE  = 4'd2;
    // S_DMA_CONFIG merged into READ behavior or separate? Let's keep separate logic but reuse state if needed.
    
    // Calc States
    localparam S_CALC_RUN   = 4'd3; 

    // Opcodes
    localparam OPC_LOAD   = 8'h02;
    localparam OPC_STORE  = 8'h03;
    localparam OPC_LOAD_W = 8'h04;
    localparam OPC_CONFIG = 8'h05;
    localparam OPC_NTT    = 8'h10;
    localparam OPC_INTT   = 8'h11;
    localparam OPC_ADD    = 8'h20;
    localparam OPC_MULT   = 8'h22;

    // --- INTERNAL SIGNALS ---
    reg [3:0] dma_state;
    reg [3:0] calc_state;
    
    // Busy Flags
    wire dma_busy  = (dma_state != S_IDLE);
    wire calc_busy = (calc_state != S_IDLE);

    // Opcode Decoding
    wire is_dma_op = (cmd_opcode == OPC_LOAD || cmd_opcode == OPC_STORE || cmd_opcode == OPC_LOAD_W || cmd_opcode == OPC_CONFIG);
    wire is_calc_op = (cmd_opcode == OPC_NTT || cmd_opcode == OPC_INTT || cmd_opcode == OPC_ADD || cmd_opcode == OPC_MULT);

    // Ready Logic: Ready if the TARGET unit is free (or if no valid command yet)
    assign ready = !cmd_valid || (is_dma_op && !dma_busy) || (is_calc_op && !calc_busy);

    // Debug
    always @(*) dbg_state = dma_state; // Or combine {dma_state, calc_state} if width allowed

    // Internal Memory & Regs
    reg [63:0] mem [0:3][0:N-1];
    reg [63:0] twiddle_ram [0:2*N-1];
    reg [63:0] q;      
    reg [63:0] mu;     
    reg [63:0] n_inv;  
    
    // DMA Vars
    reg [31:0] dma_req_idx;
    reg [31:0] dma_ack_idx;
    reg [31:0] dma_len;
    reg [47:0] reg_dma_addr;
    reg [3:0]  dma_slot;

    // Calc Vars
    reg [31:0] calc_timer;
    
    // Data Bus
    // FIXED: current_slot[1:0] truncation
    assign arb_wdata = (dma_state == S_DMA_WRITE) ? mem[dma_slot[1:0]][dma_req_idx] : 64'd0;

    // =========================================================================
    // DISPATCHER & DMA FSM
    // =========================================================================
    always @(posedge clk) begin
        if (rst) begin
            dma_state <= S_IDLE;
            arb_req <= 0;
            arb_we <= 0;
            q <= 64'h0800000000000001; // Default
            mu <= 64'd0;
            n_inv <= 64'd0;
        end else begin
            case (dma_state)
                S_IDLE: begin
                    arb_req <= 0;
                    // Latch Command if Valid AND DMA Opcode
                    if (cmd_valid && is_dma_op) begin
                        dma_slot <= cmd_slot;
                        reg_dma_addr <= cmd_dma_addr;
                        dma_req_idx <= 0;
                        dma_ack_idx <= 0;
                        
                        case (cmd_opcode)
                            OPC_LOAD:   begin dma_state <= S_DMA_READ; dma_len <= N; end
                            OPC_STORE:  begin dma_state <= S_DMA_WRITE; dma_len <= N; end
                            OPC_LOAD_W: begin dma_state <= S_DMA_READ; dma_len <= 2*N; end
                            OPC_CONFIG: begin dma_state <= S_DMA_READ; dma_len <= 3; end // Reused READ state
                            default: ;
                        endcase
                    end
                end

                S_DMA_READ: begin
                    // 1. Request
                    if (dma_req_idx < dma_len) begin
                        arb_req <= 1;
                        arb_we  <= 0;
                        arb_addr <= reg_dma_addr + (48'(dma_req_idx) * 48'd8); 
                        if (arb_gnt) dma_req_idx <= dma_req_idx + 1;
                    end else begin
                        arb_req <= 0;
                    end

                    // 2. Response
                    if (arb_valid) begin
                        if (dma_len == 3) begin
                            if (dma_ack_idx == 0) q <= arb_rdata;
                            if (dma_ack_idx == 1) mu <= arb_rdata;
                            if (dma_ack_idx == 2) n_inv <= arb_rdata;
                        end else if (dma_len == 2*N) begin
                            twiddle_ram[dma_ack_idx] <= arb_rdata;
                        end else begin
                            mem[dma_slot[1:0]][dma_ack_idx] <= arb_rdata;
                        end
                        dma_ack_idx <= dma_ack_idx + 1;
                    end

                    // 3. Exit
                    if (dma_ack_idx == dma_len) begin
                        dma_state <= S_IDLE;
                        arb_req <= 0;
                    end
                end

                S_DMA_WRITE: begin
                    if (dma_req_idx < dma_len) begin
                        arb_req <= 1;
                        arb_we  <= 1;
                        arb_addr <= reg_dma_addr + (48'(dma_req_idx) * 48'd8);
                        if (arb_gnt) dma_req_idx <= dma_req_idx + 1;
                    end else begin
                        dma_state <= S_IDLE;
                        arb_req <= 0;
                    end
                end
                
                default: dma_state <= S_IDLE;
            endcase
        end
    end

    // =========================================================================
    // CALC FSM
    // =========================================================================
    always @(posedge clk) begin
        if (rst) begin
            calc_state <= S_IDLE;
            perf_counter_out <= 0;
            calc_timer <= 0;
        end else begin
            case (calc_state)
                S_IDLE: begin
                    if (cmd_valid && is_calc_op) begin
                        calc_state <= S_CALC_RUN;
                        // Emulate execution time
                        calc_timer <= 20; // Stub: 20 cycles for any math op
                    end
                end

                S_CALC_RUN: begin
                    if (calc_timer > 0) begin
                        calc_timer <= calc_timer - 1;
                    end else begin
                        calc_state <= S_IDLE;
                        perf_counter_out <= perf_counter_out + 1;
                    end
                end
                
                default: calc_state <= S_IDLE;
            endcase
        end
    end

endmodule
