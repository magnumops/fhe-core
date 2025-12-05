module command_processor (
    input  wire        clk,
    input  wire        rst,
    
    // Dispatched Commands
    output reg         cmd_valid_0,
    output reg         cmd_valid_1,
    output reg [7:0]   cmd_opcode,
    output reg [3:0]   cmd_slot,
    output reg [47:0]  cmd_dma_addr,
    
    input  wire        engine_ready_0,
    input  wire        engine_ready_1,
    
    output reg         halted,
    output wire [1:0]  dbg_state
);
    import "DPI-C" function bit dpi_get_cmd(output bit [63:0] cmd_out);

    reg [63:0] current_cmd;
    reg target_core; // Extracted from command

    localparam S_FETCH  = 0;
    localparam S_EXEC   = 1;
    localparam S_HALTED = 2;
    reg [1:0] state;
    assign dbg_state = state;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= S_FETCH;
            cmd_valid_0 <= 0;
            cmd_valid_1 <= 0;
            halted <= 0;
        end else begin
            case (state)
                S_FETCH: begin
                    cmd_valid_0 <= 0;
                    cmd_valid_1 <= 0;
                    
                    // Simple logic: we fetch if BOTH engines are ready?
                    // Or if at least the target engine is ready?
                    // Since we don't know the target before fetch, we wait for BOTH for safety in V1.
                    // Optimisation: Peek queue? Too complex for DPI.
                    // Let's wait for both to be safe.
                    if (engine_ready_0 && engine_ready_1) begin
                        if (dpi_get_cmd(current_cmd)) begin
                            if (current_cmd[63:56] == 8'h00) begin
                                state <= S_HALTED;
                                halted <= 1;
                            end else begin
                                cmd_opcode <= current_cmd[63:56];
                                cmd_slot     <= current_cmd[55:52];
                                // Bit 48 is Target Core ID
                                target_core  <= current_cmd[48]; 
                                // Mask out the core bit for the address
                                cmd_dma_addr <= current_cmd[47:0]; 
                                
                                if (current_cmd[48] == 0) cmd_valid_0 <= 1;
                                else                      cmd_valid_1 <= 1;
                                
                                state <= S_EXEC;
                            end
                        end
                    end
                end

                S_EXEC: begin
                    cmd_valid_0 <= 0;
                    cmd_valid_1 <= 0;
                    state <= S_FETCH;
                end

                S_HALTED: halted <= 1;
            endcase
        end
    end
endmodule
