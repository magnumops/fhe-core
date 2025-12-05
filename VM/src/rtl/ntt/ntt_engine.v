module ntt_engine #(
    parameter N_LOG = 12,
    parameter N     = 4096
)(
    input  wire        clk,
    input  wire        rst,
    input  wire        cmd_valid,
    input  wire [7:0]  cmd_opcode,
    input  wire [3:0]  cmd_slot,      
    input  wire [47:0] cmd_dma_addr,  
    input  wire [63:0] q,
    input  wire [63:0] mu,
    input  wire [63:0] n_inv,
    output reg         ready,
    output wire [2:0]  dbg_state
);

    import "DPI-C" function void dpi_read_burst(input longint addr, input int len, output bit [63:0] data []);
    import "DPI-C" function void dpi_write_burst(input longint addr, input int len, input bit [63:0] data []);

    bit [63:0] mem [0:3][0:N-1];
    bit [63:0] w_mem [0:8191];

    reg [1:0] current_slot; 
    reg [1:0] source_slot;  
    reg       mode_intt;
    reg       agu_start;
    wire      agu_valid, agu_done;
    wire [N_LOG-1:0] agu_addr_u, agu_addr_v, agu_addr_w;

    // --- Performance Counters (ISOLATED BLOCK) ---
    reg [63:0] perf_total_cycles = 0;
    reg [63:0] perf_active_cycles = 0;
    reg [63:0] perf_ntt_ops = 0;
    reg [63:0] perf_alu_ops = 0;
    bit [63:0] perf_buffer [0:3]; 

    // Trigger signals for increments
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
        .u(u_in), .v(v_in), .w(w_data), .q(q), .mu(mu),
        .u_out(u_out), .v_out(v_out)
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
        .op_a(alu_op_a), .op_b(alu_op_b), .q(q), .mu(mu),
        .res_out(alu_res)
    );

    localparam [7:0] OPC_LOAD   = 8'h02;
    localparam [7:0] OPC_STORE  = 8'h03;
    localparam [7:0] OPC_LOAD_W = 8'h04;
    localparam [7:0] OPC_READ_PERF = 8'h0F;
    localparam [7:0] OPC_NTT    = 8'h10;
    localparam [7:0] OPC_INTT   = 8'h11;
    localparam [7:0] OPC_ADD    = 8'h20;
    localparam [7:0] OPC_SUB    = 8'h21;
    localparam [7:0] OPC_MULT   = 8'h22;

    // --- ISOLATED COUNTER LOGIC (NO RESET) ---
    always @(posedge clk) begin
        perf_total_cycles <= perf_total_cycles + 1;
        
        if (state != S_IDLE) 
            perf_active_cycles <= perf_active_cycles + 1;
            
        if (inc_ntt_pulse) perf_ntt_ops <= perf_ntt_ops + 1;
        if (inc_alu_pulse) perf_alu_ops <= perf_alu_ops + 1;
    end

    // --- MAIN FSM ---
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= S_IDLE;
            ready <= 1;
            agu_start <= 0;
            current_slot <= 0;
            alu_idx <= 0;
            inc_ntt_pulse <= 0;
            inc_alu_pulse <= 0;
        end else begin
            // Reset pulse triggers by default
            inc_ntt_pulse <= 0;
            inc_alu_pulse <= 0;

            case (state)
                S_IDLE: begin
                    ready <= 1;
                    if (cmd_valid) begin
                        ready <= 0;
                        current_slot <= cmd_slot[1:0];
                        source_slot  <= cmd_dma_addr[47:46];

                        case (cmd_opcode)
                            OPC_LOAD:   state <= S_DMA_READ;
                            OPC_STORE:  state <= S_DMA_WRITE;
                            OPC_LOAD_W: state <= S_LOAD_W;
                            OPC_READ_PERF: state <= S_PERF_DUMP; 
                            OPC_NTT: begin
                                mode_intt <= 0;
                                state <= S_CALC;
                                agu_start <= 1;
                                inc_ntt_pulse <= 1; // Trigger increment
                            end
                            OPC_INTT: begin
                                mode_intt <= 1;
                                state <= S_CALC;
                                agu_start <= 1;
                                inc_ntt_pulse <= 1; // Trigger increment
                            end
                            OPC_ADD: begin
                                alu_opcode_reg <= 3'b000;
                                state <= S_ALU;
                                alu_idx <= 0;
                                inc_alu_pulse <= 1; // Trigger increment
                            end
                            OPC_SUB: begin
                                alu_opcode_reg <= 3'b001;
                                state <= S_ALU;
                                alu_idx <= 0;
                                inc_alu_pulse <= 1; // Trigger increment
                            end
                            OPC_MULT: begin
                                alu_opcode_reg <= 3'b010;
                                state <= S_ALU;
                                alu_idx <= 0;
                                inc_alu_pulse <= 1; // Trigger increment
                            end
                            default: state <= S_IDLE;
                        endcase
                    end
                end

                S_DMA_READ: begin
                    dpi_read_burst({16'b0, cmd_dma_addr}, N, mem[current_slot]);
                    state <= S_IDLE;
                end

                S_DMA_WRITE: begin
                    dpi_write_burst({16'b0, cmd_dma_addr}, N, mem[current_slot]);
                    state <= S_IDLE;
                end

                S_LOAD_W: begin
                    dpi_read_burst({16'b0, cmd_dma_addr}, 2*N, w_mem);
                    state <= S_IDLE;
                end

                S_PERF_DUMP: begin
                    perf_buffer[0] = perf_total_cycles;
                    perf_buffer[1] = perf_active_cycles;
                    perf_buffer[2] = perf_ntt_ops;
                    perf_buffer[3] = perf_alu_ops;
                    dpi_write_burst({16'b0, cmd_dma_addr}, 4, perf_buffer);
                    state <= S_IDLE;
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
