module ntt_engine #(
    parameter N_LOG = 3,
    parameter N     = 8
)(
    input  wire        clk,
    input  wire        rst,
    // Control Interface
    input  wire        start,
    output wire        done,
    
    // Data Loading/Reading Interface
    input  wire        rw_mode,      // 1=Write(Load), 0=Read(Debug)
    input  wire [N_LOG-1:0] rw_addr,
    input  wire [63:0] rw_data_in,
    output reg  [63:0] rw_data_out
);

    // --- INTERNAL MEMORY (Distributed RAM for N=8) ---
    reg [63:0] mem [0:N-1];

    // --- AGU SIGNALS ---
    wire [N_LOG-1:0] agu_addr_u, agu_addr_v, agu_addr_w;
    wire agu_valid, agu_done;

    // --- AGU INSTANCE ---
    ntt_control #(.N_LOG(N_LOG), .N(N)) u_control (
        .clk(clk), .rst(rst), .start(start),
        .addr_u(agu_addr_u), .addr_v(agu_addr_v), .addr_w(agu_addr_w),
        .valid(agu_valid), .done(agu_done)
    );
    
    assign done = agu_done;

    // --- ROM INSTANCE ---
    wire [63:0] w_data;
    // Внимание: ROM у нас на 3 бита адреса (Hardcoded N=8 in twiddle_rom.v)
    // Для универсальности потом переделаем, но сейчас мапим напрямую.
    twiddle_rom u_rom (
        .addr(agu_addr_w[2:0]), 
        .data(w_data)
    );

    // --- MEMORY READ (Async) ---
    // Читаем данные по адресам от AGU
    wire [63:0] u_in = mem[agu_addr_u];
    wire [63:0] v_in = mem[agu_addr_v];

    // --- BUTTERFLY INSTANCE ---
    wire [63:0] u_out, v_out;
    // Q хардкодим 17 для теста, как и везде пока
    wire [63:0] const_q = 17;

    butterfly u_bf (
        .u(u_in), .v(v_in), .w(w_data), .q(const_q),
        .u_out(u_out), .v_out(v_out)
    );

    // --- MAIN PROCESS ---
    always @(posedge clk) begin
        // 1. External Access (Loading/Reading)
        // Приоритет загрузки над вычислениями (или предполагаем, что start=0 при загрузке)
        if (!start && !agu_valid) begin
            if (rw_mode) begin
                // Write
                mem[rw_addr] <= rw_data_in;
            end
            // Read is async usually, but let's register it for stability
            rw_data_out <= mem[rw_addr];
        end

        // 2. NTT Calculation
        if (agu_valid) begin
            // In-Place Write Back
            mem[agu_addr_u] <= u_out;
            mem[agu_addr_v] <= v_out;
        end
    end

endmodule
