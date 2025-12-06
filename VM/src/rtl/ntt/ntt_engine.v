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
    output reg         ready,

    // Arbiter Interface
    output reg         arb_req,
    output reg         arb_we,
    output reg [47:0]  arb_addr,
    output wire [63:0] arb_wdata,
    input  wire        arb_gnt,
    input  wire        arb_valid,
    input  wire [63:0] arb_rdata,

    // Debug & Metrics
    output reg [3:0]   dbg_state,
    output reg [63:0]  perf_counter_out // FIXED: Upgraded to 64-bit
);

    // States
    localparam S_IDLE           = 4'd0;
    localparam S_DMA_READ       = 4'd1;
    localparam S_DMA_WRITE      = 4'd2;
    localparam S_CALC           = 4'd3;
    localparam S_DMA_CONFIG     = 4'd4;
    localparam S_ALU            = 4'd5;
    localparam S_DONE           = 4'd6;

    // Opcodes
    localparam OPC_LOAD   = 8'h02;
    localparam OPC_STORE  = 8'h03;
    localparam OPC_LOAD_W = 8'h04;
    localparam OPC_CONFIG = 8'h05;
    localparam OPC_NTT    = 8'h10;
    localparam OPC_INTT   = 8'h11;
    localparam OPC_ADD    = 8'h20;
    localparam OPC_MULT   = 8'h22;

    reg [3:0] state;
    assign dbg_state = state;

    // Internal Memory
    reg [63:0] mem [0:3][0:N-1];
    reg [63:0] twiddle_ram [0:2*N-1];

    // Registers (64-bit for RNS)
    reg [63:0] q;      
    reg [63:0] mu;     
    reg [63:0] n_inv;  
    
    // DMA Counters
    reg [31:0] dma_req_idx;
    reg [31:0] dma_ack_idx;
    reg [31:0] dma_len;
    reg [47:0] reg_dma_addr;
    reg [3:0]  current_slot;

    // Data Bus Logic
    // FIXED: current_slot[1:0] truncation to satisfy Verilator
    assign arb_wdata = (state == S_DMA_WRITE) ? mem[current_slot[1:0]][dma_req_idx] : 64'd0;

    always @(posedge clk) begin
        if (rst) begin
            state <= S_IDLE;
            ready <= 1;
            arb_req <= 0;
            arb_we <= 0;
            perf_counter_out <= 0;
            
            q <= 64'h0800000000000001;
            mu <= 64'd0;
            n_inv <= 64'd0;
            dma_req_idx <= 0;
            dma_ack_idx <= 0;
        end else begin
            case (state)
                S_IDLE: begin
                    arb_req <= 0;
                    ready <= 1;
                    if (cmd_valid) begin
                        ready <= 0;
                        current_slot <= cmd_slot;
                        reg_dma_addr <= cmd_dma_addr;
                        dma_req_idx <= 0;
                        dma_ack_idx <= 0;
                        
                        case (cmd_opcode)
                            OPC_LOAD:   begin state <= S_DMA_READ; dma_len <= N; end
                            OPC_STORE:  begin state <= S_DMA_WRITE; dma_len <= N; end
                            OPC_LOAD_W: begin state <= S_DMA_READ; dma_len <= 2*N; end
                            OPC_CONFIG: begin state <= S_DMA_CONFIG; dma_len <= 3; end
                            OPC_NTT:    begin state <= S_CALC; end
                            OPC_ADD:    begin state <= S_ALU; end
                            OPC_MULT:   begin state <= S_ALU; end
                            default:    state <= S_DONE;
                        endcase
                    end
                end

                // --- PIPELINED DMA READ ---
                S_DMA_READ: begin
                    // Request Logic
                    if (dma_req_idx < dma_len) begin
                        arb_req <= 1;
                        arb_we  <= 0;
                        arb_addr <= reg_dma_addr + (48'(dma_req_idx) * 48'd8); 
                        if (arb_gnt) dma_req_idx <= dma_req_idx + 1;
                    end else begin
                        arb_req <= 0;
                    end

                    // Response Logic
                    if (arb_valid) begin
                        if (dma_len == 3) begin
                            if (dma_ack_idx == 0) q <= arb_rdata;
                            if (dma_ack_idx == 1) mu <= arb_rdata;
                            if (dma_ack_idx == 2) n_inv <= arb_rdata;
                        end else if (dma_len == 2*N) begin
                            twiddle_ram[dma_ack_idx] <= arb_rdata;
                        end else begin
                            // FIXED: current_slot[1:0]
                            mem[current_slot[1:0]][dma_ack_idx] <= arb_rdata;
                        end
                        dma_ack_idx <= dma_ack_idx + 1;
                    end

                    // Exit
                    if (dma_ack_idx == dma_len) begin
                        state <= S_DONE;
                        arb_req <= 0;
                    end
                end

                S_DMA_CONFIG: state <= S_DMA_READ;

                // --- PIPELINED DMA WRITE ---
                S_DMA_WRITE: begin
                    if (dma_req_idx < dma_len) begin
                        arb_req <= 1;
                        arb_we  <= 1;
                        arb_addr <= reg_dma_addr + (48'(dma_req_idx) * 48'd8);
                        if (arb_gnt) dma_req_idx <= dma_req_idx + 1;
                    end else begin
                        state <= S_DONE;
                        arb_req <= 0;
                    end
                end

                S_CALC: begin
                    perf_counter_out <= perf_counter_out + 1;
                    state <= S_DONE;
                end
                
                S_ALU: begin
                    perf_counter_out <= perf_counter_out + 1;
                    state <= S_DONE;
                end

                S_DONE: begin
                    ready <= 1;
                    state <= S_IDLE;
                end
                
                default: state <= S_IDLE;
            endcase
        end
    end
endmodule
