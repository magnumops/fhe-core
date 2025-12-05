module command_processor(
    input clk, input rst,
    input cmd_valid, input [63:0] cmd_data, output reg cmd_ready,
    output reg core0_start, output reg core1_start, output reg dma_start,
    input core0_ready, input core1_ready, input dma_ready,
    output reg halted
);
    localparam CMD_HALT = 8'h00;
    localparam CMD_NTT  = 8'h01; 
    localparam CMD_DMA  = 8'h02; // New Command

    wire engines_idle = core0_ready && core1_ready && dma_ready;
    reg halt_pending;

    always @(posedge clk) begin
        if (rst) begin
            halted <= 0;
            core0_start <= 0; core1_start <= 0; dma_start <= 0;
            cmd_ready <= 1;
            halt_pending <= 0;
        end else begin
            core0_start <= 0; core1_start <= 0; dma_start <= 0;

            if (cmd_valid && cmd_ready) begin
                /* verilator lint_off CASEINCOMPLETE */
                case (cmd_data[63:56])
                    CMD_HALT: halt_pending <= 1;
                    CMD_NTT: begin
                        if (cmd_data[55] == 0) core0_start <= 1;
                        else core1_start <= 1;
                    end
                    CMD_DMA: dma_start <= 1;
                endcase
                /* verilator lint_on CASEINCOMPLETE */
            end
            
            if (halt_pending && engines_idle) halted <= 1;
        end
    end
endmodule
