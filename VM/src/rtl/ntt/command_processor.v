module command_processor (
    input  wire        clk,
    input  wire        rst,
    // Interface to Engine
    output reg         cmd_valid,      // Strobe for any command
    output reg [7:0]   cmd_opcode,     // The opcode itself
    output reg [3:0]   cmd_slot,       // Target Slot
    output reg [47:0]  cmd_dma_addr,   // DMA Address (for Load/Store)
    input  wire        engine_ready,   // Engine is idle/ready
    // Global Status
    output reg         halted
);
    import "DPI-C" function bit dpi_get_cmd(output bit [63:0] cmd_out);

    reg [63:0] current_cmd;
    localparam S_FETCH  = 0;
    localparam S_EXEC   = 1;
    localparam S_HALTED = 2;
    reg [1:0] state;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= S_FETCH;
            cmd_valid <= 0;
            halted <= 0;
        end else begin
            case (state)
                S_FETCH: begin
                    cmd_valid <= 0;
                    if (engine_ready && dpi_get_cmd(current_cmd)) begin
                        // Decode immediately
                        if (current_cmd[63:56] == 8'h00) begin // HALT
                            state <= S_HALTED;
                            halted <= 1;
                        end else begin
                            cmd_opcode <= current_cmd[63:56];
                            // Parsing Payload: [63:56] Op | [55:52] Slot | [47:0] Addr
                            cmd_slot     <= current_cmd[55:52];
                            cmd_dma_addr <= current_cmd[47:0];
                            cmd_valid    <= 1; // Pulse for 1 cycle (next state will clear)
                            state <= S_EXEC;
                        end
                    end
                end

                S_EXEC: begin
                    cmd_valid <= 0;
                    // Wait for engine to accept (it should catch valid in this cycle)
                    // Go back to fetch immediately? 
                    // To be safe, wait 1 cycle or check ready?
                    // Engine sets 'ready' to 0 when it starts processing.
                    state <= S_FETCH; 
                end

                S_HALTED: halted <= 1;
            endcase
        end
    end
endmodule
