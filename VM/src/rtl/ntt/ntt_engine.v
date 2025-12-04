module ntt_engine #(
    parameter N_LOG = 12,
    parameter N     = 4096
)(
    input  wire        clk,
    input  wire        rst,
    // Control
    input  wire        start,
    input  wire        mode,     // 0 = NTT (Forward), 1 = INTT (Inverse)
    input  wire [63:0] dma_addr,
    output reg         done
);

    import "DPI-C" function void dpi_read_burst(input longint addr, input int len, output bit [63:0] data []);
    import "DPI-C" function void dpi_write_burst(input longint addr, input int len, input bit [63:0] data []);

    // Memory (2-state bit)
    bit [63:0] mem [0:N-1];

    // AGU
    wire [N_LOG-1:0] agu_addr_u, agu_addr_v, agu_addr_w;
    wire agu_valid, agu_done;
    reg  agu_start;

    // FSM
    localparam S_IDLE  = 0;
    localparam S_LOAD  = 1;
    localparam S_CALC  = 2;
    localparam S_SCALE = 3; // New: Scaling for INTT
    localparam S_STORE = 4;
    localparam S_DONE  = 5;

    reg [2:0] state;

    ntt_control #(.N_LOG(N_LOG), .N(N)) u_control (
        .clk(clk), .rst(rst), .start(agu_start),
        .addr_u(agu_addr_u), .addr_v(agu_addr_v), .addr_w(agu_addr_w),
        .valid(agu_valid), .done(agu_done)
    );

    // ROM: Address is {mode, agu_addr_w}
    wire [63:0] w_data;
    twiddle_rom u_rom (.addr({mode, agu_addr_w}), .data(w_data));

    // Butterfly
    // N_INV хардкодим (вставляем через sed далее, или используем const)
    // Placeholder будет заменен
    wire [63:0] const_q = 1073750017;
    wire [63:0] const_n_inv = 1073487871;

    wire [63:0] u_in = mem[agu_addr_u];
    wire [63:0] v_in = mem[agu_addr_v];
    wire [63:0] u_out, v_out;

    butterfly u_bf (
        .u(u_in), .v(v_in), .w(w_data), .q(const_q),
        .u_out(u_out), .v_out(v_out)
    );
    
    // --- SCALER Logic (For INTT) ---
    reg [N_LOG:0] scale_idx; // up to N
    wire [63:0] scale_in = mem[scale_idx[N_LOG-1:0]];
    wire [63:0] scale_out;
    
    mod_mult u_scaler (
        .a(scale_in), .b(const_n_inv), .q(const_q), .out(scale_out)
    );

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= S_IDLE;
            done <= 0;
            agu_start <= 0;
            scale_idx <= 0;
        end else begin
            case (state)
                S_IDLE: begin
                    done <= 0;
                    if (start) state <= S_LOAD;
                end

                S_LOAD: begin
                    dpi_read_burst(dma_addr, N, mem); 
                    state <= S_CALC;
                    agu_start <= 1;
                end

                S_CALC: begin
                    agu_start <= 0;
                    if (agu_valid) begin
                        mem[agu_addr_u] <= u_out;
                        mem[agu_addr_v] <= v_out;
                    end
                    if (agu_done) begin
                        if (mode == 1) begin
                            state <= S_SCALE;
                            scale_idx <= 0;
                        end else begin
                            state <= S_STORE;
                        end
                    end
                end
                
                S_SCALE: begin
                    // Simple serial scaler: 1 word per cycle? 
                    // No, READ -> MULT -> WRITE latency.
                    // Distributed RAM usually supports Read-Mod-Write in 1 cycle if clock edge aligns.
                    // Let's assume sync write, async read.
                    // Cycle T: Addr=0 set. Data 0 read async. Mult computes. Write happens at T+1 edge?
                    // Let's do it safely: Write happens at end of cycle.
                    // But we need to increment idx.
                    
                    if (scale_idx < N) begin
                        mem[scale_idx[N_LOG-1:0]] <= scale_out;
                        scale_idx <= scale_idx + 1;
                    end else begin
                        state <= S_STORE;
                    end
                end

                S_STORE: begin
                    dpi_write_burst(dma_addr, N, mem);
                    state <= S_DONE;
                end

                S_DONE: begin
                    done <= 1;
                    if (!start) state <= S_IDLE;
                end
            endcase
        end
    end
endmodule
