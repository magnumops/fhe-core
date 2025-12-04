module ntt_engine #(
    parameter N_LOG = 3,
    parameter N     = 8
)(
    input  wire        clk,
    input  wire        rst,
    // Control
    input  wire        start,
    input  wire [63:0] dma_addr,
    output reg         done
);

    // --- DPI IMPORT ---
    import "DPI-C" function void dpi_read_burst(input longint addr, input int len, output bit [63:0] data []);
    import "DPI-C" function void dpi_write_burst(input longint addr, input int len, input bit [63:0] data []);

    // --- INTERNAL MEMORY ---
    // FIX: Используем 'bit' (2-state) вместо 'reg' для совместимости с DPI Open Arrays
    bit [63:0] mem [0:N-1];

    // --- AGU SIGNALS ---
    wire [N_LOG-1:0] agu_addr_u, agu_addr_v, agu_addr_w;
    wire agu_valid, agu_done;
    reg  agu_start;

    // --- FSM STATE ---
    localparam S_IDLE  = 0;
    localparam S_LOAD  = 1;
    localparam S_CALC  = 2;
    localparam S_STORE = 3;
    localparam S_DONE  = 4;

    reg [2:0] state;

    ntt_control #(.N_LOG(N_LOG), .N(N)) u_control (
        .clk(clk), .rst(rst), .start(agu_start),
        .addr_u(agu_addr_u), .addr_v(agu_addr_v), .addr_w(agu_addr_w),
        .valid(agu_valid), .done(agu_done)
    );

    wire [63:0] w_data;
    twiddle_rom u_rom (.addr(agu_addr_w[2:0]), .data(w_data));

    wire [63:0] u_in = mem[agu_addr_u];
    wire [63:0] v_in = mem[agu_addr_v];
    wire [63:0] u_out, v_out;
    wire [63:0] const_q = 17;

    butterfly u_bf (
        .u(u_in), .v(v_in), .w(w_data), .q(const_q),
        .u_out(u_out), .v_out(v_out)
    );

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= S_IDLE;
            done <= 0;
            agu_start <= 0;
        end else begin
            case (state)
                S_IDLE: begin
                    done <= 0;
                    if (start) begin
                        state <= S_LOAD;
                    end
                end

                S_LOAD: begin
                    // DPI call now works correctly with 'bit' array
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
