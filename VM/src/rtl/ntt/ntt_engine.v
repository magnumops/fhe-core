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
    
    // Twiddle RAM (Size 2*N for Forward+Inverse)
    bit [63:0] w_mem [0:8191]; 

    reg [1:0] current_slot;
    reg       mode_intt;
    reg       agu_start;
    wire      agu_valid, agu_done;
    wire [N_LOG-1:0] agu_addr_u, agu_addr_v, agu_addr_w;

    localparam S_IDLE      = 0;
    localparam S_DMA_READ  = 1;
    localparam S_DMA_WRITE = 2;
    localparam S_LOAD_W    = 3; 
    localparam S_CALC      = 4;
    localparam S_SCALE     = 5; 
    
    reg [2:0] state;
    assign dbg_state = state;

    ntt_control #(.N_LOG(N_LOG), .N(N)) u_control (
        .clk(clk), .rst(rst), .start(agu_start),
        .addr_u(agu_addr_u), .addr_v(agu_addr_v), .addr_w(agu_addr_w),
        .valid(agu_valid), .done(agu_done)
    );

    // Read Twiddles: Base address depends on mode
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

    localparam [7:0] OPC_LOAD   = 8'h02;
    localparam [7:0] OPC_STORE  = 8'h03;
    localparam [7:0] OPC_LOAD_W = 8'h04;
    localparam [7:0] OPC_NTT    = 8'h10;
    localparam [7:0] OPC_INTT   = 8'h11;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= S_IDLE;
            ready <= 1;
            agu_start <= 0;
            current_slot <= 0;
        end else begin
            case (state)
                S_IDLE: begin
                    ready <= 1;
                    if (cmd_valid) begin
                        ready <= 0;
                        current_slot <= cmd_slot[1:0];
                        
                        case (cmd_opcode)
                            OPC_LOAD:   state <= S_DMA_READ;
                            OPC_STORE:  state <= S_DMA_WRITE;
                            OPC_LOAD_W: state <= S_LOAD_W;
                            OPC_NTT: begin
                                mode_intt <= 0;
                                state <= S_CALC;
                                agu_start <= 1;
                            end
                            OPC_INTT: begin
                                mode_intt <= 1;
                                state <= S_CALC;
                                agu_start <= 1;
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
                    // Load 2*N words (Forward + Inverse)
                    dpi_read_burst({16'b0, cmd_dma_addr}, 2*N, w_mem);
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
            endcase
        end
    end
endmodule
