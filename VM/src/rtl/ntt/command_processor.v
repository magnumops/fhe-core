module command_processor (
    input  wire        clk,
    input  wire        rst,
    output reg         cmd_valid,
    output reg [7:0]   cmd_opcode,
    output reg [3:0]   cmd_slot,
    output reg [47:0]  cmd_dma_addr,
    input  wire        engine_ready,
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
                    // Only log if we actually try to fetch
                    if (engine_ready) begin
                        if (dpi_get_cmd(current_cmd)) begin
                            $display("[CPU] Fetched CMD: %h", current_cmd);
                            if (current_cmd[63:56] == 8'h00) begin
                                state <= S_HALTED;
                                halted <= 1;
                                $display("[CPU] HALTING");
                            end else begin
                                cmd_opcode <= current_cmd[63:56];
                                cmd_slot     <= current_cmd[55:52];
                                cmd_dma_addr <= current_cmd[47:0];
                                cmd_valid    <= 1; 
                                state <= S_EXEC;
                            end
                        end
                    end
                end

                S_EXEC: begin
                    cmd_valid <= 0;
                    state <= S_FETCH; 
                end

                S_HALTED: halted <= 1;
            endcase
        end
    end
endmodule
