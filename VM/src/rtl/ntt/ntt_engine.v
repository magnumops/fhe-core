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
    
    output reg         arb_req,
    output reg         arb_we,
    output reg [47:0]  arb_addr,
    output wire [63:0] arb_wdata, 
    input  wire        arb_gnt,
    input  wire        arb_valid,
    input  wire [63:0] arb_rdata,

    output wire [2:0]  dbg_state,
    output wire [63:0] perf_counter_out
);

    reg [63:0] mem [0:3][0:N-1];
    reg [63:0] w_mem [0:2*N-1];
    
    reg [63:0] q;
    reg [63:0] mu;
    reg [63:0] n_inv;

    reg [1:0]  current_slot;
    reg [1:0]  source_slot;
    
    // INTERNAL COMMAND REGISTERS (The Fix)
    reg [47:0] reg_dma_addr;
    reg [7:0]  reg_opcode;
    
    reg        mode_intt;
    reg        agu_start;
    wire       agu_valid, agu_done;
    wire [N_LOG-1:0] agu_addr_u, agu_addr_v, agu_addr_w;

    reg [63:0] perf_ntt_ops;
    assign perf_counter_out = perf_ntt_ops;

    localparam S_IDLE         = 0;
    localparam S_DMA_READ_REQ = 1; 
    localparam S_DMA_READ_WAIT= 2;
    localparam S_DMA_WRITE    = 3;
    localparam S_CALC         = 4;
    localparam S_DMA_CONFIG   = 5;
    localparam S_ALU          = 6;

    reg [2:0] state;
    assign dbg_state = state;

    localparam [7:0] OPC_LOAD   = 8'h02;
    localparam [7:0] OPC_STORE  = 8'h03;
    localparam [7:0] OPC_LOAD_W = 8'h04;
    localparam [7:0] OPC_CONFIG = 8'h05;
    localparam [7:0] OPC_NTT    = 8'h10;
    localparam [7:0] OPC_INTT   = 8'h11;
    localparam [7:0] OPC_ADD    = 8'h20;
    localparam [7:0] OPC_SUB    = 8'h21;
    localparam [7:0] OPC_MULT   = 8'h22;

    reg [31:0] dma_req_idx; 
    reg [31:0] dma_ack_idx; 
    reg [31:0] dma_len;
    
    reg [N_LOG:0] alu_idx;
    reg [2:0]     alu_opcode_reg;

    ntt_control #(.N_LOG(N_LOG), .N(N)) u_control (
        .clk(clk), .rst(rst), .start(agu_start),
        .addr_u(agu_addr_u), .addr_v(agu_addr_v), .addr_w(agu_addr_w),
        .valid(agu_valid), .done(agu_done)
    );
    
    wire [N_LOG:0] w_addr_full = {mode_intt, agu_addr_w};
    wire [63:0] w_data = w_mem[w_addr_full];
    wire [63:0] u_in = mem[current_slot][agu_addr_u];
    wire [63:0] v_in = mem[current_slot][agu_addr_v];
    wire [63:0] u_out, v_out;

    butterfly u_bf (
        .u(u_in), .v(v_in), .w(w_data), .q(q), .mu(mu), .u_out(u_out), .v_out(v_out)
    );
    
    wire [63:0] alu_in_a = mem[current_slot][alu_idx[N_LOG-1:0]];
    wire [63:0] alu_in_b = mem[source_slot][alu_idx[N_LOG-1:0]];
    wire [63:0] alu_out;
    
    vec_alu u_vec_alu (
        .opcode(alu_opcode_reg),
        .op_a(alu_in_a), .op_b(alu_in_b), .q(q), .mu(mu), .res_out(alu_out)
    );

    assign arb_wdata = (state == S_DMA_WRITE) ? mem[current_slot][dma_req_idx] : 64'd0;

    always @(posedge clk) begin
        if (rst) perf_ntt_ops <= 0;
        else begin
            if (state == S_CALC && agu_valid) perf_ntt_ops <= perf_ntt_ops + 1;
            if (state == S_ALU) perf_ntt_ops <= perf_ntt_ops + 1;
        end
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= S_IDLE;
            ready <= 1;
            agu_start <= 0;
            arb_req <= 0;
            q <= 64'h0800000000000001; 
            mu <= 0; n_inv <= 0;
            alu_idx <= 0;
        end else begin
            if (arb_valid) begin
                 if (state == S_DMA_READ_REQ) begin
                    // Use Registered Opcode
                    if (reg_opcode == OPC_LOAD_W) w_mem[dma_ack_idx] <= arb_rdata;
                    else mem[current_slot][dma_ack_idx] <= arb_rdata;
                    dma_ack_idx <= dma_ack_idx + 1;
                 end
                 if (state == S_DMA_CONFIG) begin
                    case (dma_ack_idx)
                        0: q <= arb_rdata;
                        1: mu <= arb_rdata;
                        2: n_inv <= arb_rdata;
                    endcase
                    dma_ack_idx <= dma_ack_idx + 1;
                 end
            end
            
            if (state == S_CALC && agu_valid) begin
                mem[current_slot][agu_addr_u] <= u_out;
                mem[current_slot][agu_addr_v] <= v_out;
            end
            
            if (state == S_ALU) begin
                if (alu_idx < N) begin
                    mem[current_slot][alu_idx[N_LOG-1:0]] <= alu_out;
                    alu_idx <= alu_idx + 1;
                end else begin
                    state <= S_IDLE;
                end
            end

            case (state)
                S_IDLE: begin
                    ready <= 1;
                    dma_req_idx <= 0;
                    dma_ack_idx <= 0;
                    arb_req <= 0;
                    if (cmd_valid) begin
                        $display("[RTL Core%0d] CMD: Op=%h Addr=%h", CORE_ID, cmd_opcode, cmd_dma_addr);
                        ready <= 0;
                        current_slot <= cmd_slot[1:0];
                        source_slot  <= cmd_dma_addr[1:0]; 
                        
                        // LATCH INPUTS
                        reg_dma_addr <= cmd_dma_addr;
                        reg_opcode   <= cmd_opcode;
                        
                        case (cmd_opcode)
                            OPC_LOAD: begin state <= S_DMA_READ_REQ; dma_len <= N; arb_addr <= cmd_dma_addr; end
                            OPC_STORE: begin state <= S_DMA_WRITE; dma_len <= N; arb_addr <= cmd_dma_addr; end
                            OPC_LOAD_W: begin state <= S_DMA_READ_REQ; dma_len <= 2*N; arb_addr <= cmd_dma_addr; end
                            OPC_CONFIG: begin state <= S_DMA_CONFIG; dma_len <= 3; arb_addr <= cmd_dma_addr; end
                            OPC_NTT: begin state <= S_CALC; mode_intt <= 0; agu_start <= 1; end
                            OPC_INTT: begin state <= S_CALC; mode_intt <= 1; agu_start <= 1; end
                            OPC_ADD: begin state <= S_ALU; alu_idx <= 0; alu_opcode_reg <= 3'b000; end
                            OPC_SUB: begin state <= S_ALU; alu_idx <= 0; alu_opcode_reg <= 3'b001; end
                            OPC_MULT: begin state <= S_ALU; alu_idx <= 0; alu_opcode_reg <= 3'b010; end
                            default: state <= S_IDLE;
                        endcase
                    end
                end
                
                S_DMA_READ_REQ: begin
                    if (dma_req_idx < dma_len && dma_req_idx == dma_ack_idx) begin
                        arb_req <= 1; arb_we <= 0;
                        if (arb_gnt) begin 
                            dma_req_idx <= dma_req_idx + 1; 
                            // USE REGISTERED ADDRESS
                            arb_addr <= reg_dma_addr + ((dma_req_idx + 1) * 8); 
                            arb_req <= 0; 
                        end
                    end else arb_req <= 0;
                    if (dma_ack_idx >= dma_len) state <= S_IDLE;
                end
                
                S_DMA_WRITE: begin
                    if (dma_req_idx < dma_len) begin
                        arb_req <= 1; arb_we <= 1;
                        if (arb_gnt) begin 
                            dma_req_idx <= dma_req_idx + 1; 
                            // USE REGISTERED ADDRESS
                            arb_addr <= reg_dma_addr + ((dma_req_idx + 1) * 8);
                        end
                    end else begin arb_req <= 0; state <= S_IDLE; end
                end
                
                S_DMA_CONFIG: begin
                    if (dma_req_idx < dma_len && dma_req_idx == dma_ack_idx) begin
                        arb_req <= 1; arb_we <= 0;
                        if (arb_gnt) begin 
                            dma_req_idx <= dma_req_idx + 1; 
                            // USE REGISTERED ADDRESS
                            arb_addr <= reg_dma_addr + ((dma_req_idx + 1) * 8); 
                            arb_req <= 0; 
                        end
                    end else arb_req <= 0;
                    if (dma_ack_idx >= dma_len) state <= S_IDLE;
                end

                S_CALC: begin
                    agu_start <= 0;
                    if (agu_done) state <= S_IDLE;
                end
            endcase
        end
    end
endmodule
