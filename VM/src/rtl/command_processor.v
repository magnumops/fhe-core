module command_processor(
    input clk, input rst,
    input cmd_valid, input [63:0] cmd_data, 
    output wire cmd_ready, 
    
    // Core Interfaces
    output reg core0_start, output reg core1_start,
    input core0_ready, input core1_ready,
    
    // DMA Interface (ВОССТАНОВЛЕНО)
    output reg dma_start,
    input dma_ready,
    
    output reg halted
);
    localparam CMD_HALT = 8'h00;
    localparam CMD_NTT  = 8'h01; 
    localparam CMD_DMA  = 8'h02; 
    
    // Мы свободны, только если ВСЕ устройства свободны
    wire engines_idle = core0_ready && core1_ready && dma_ready;
    reg halt_pending;

    // --- Backpressure Logic ---
    wire is_ntt = (cmd_data[63:56] == CMD_NTT);
    wire is_dma = (cmd_data[63:56] == CMD_DMA);
    
    wire target_c0 = is_ntt && (cmd_data[55] == 0);
    wire target_c1 = is_ntt && (cmd_data[55] == 1);
    
    // Если целевое устройство занято - мы не готовы (Stall)
    wire stall = (target_c0 && !core0_ready) || 
                 (target_c1 && !core1_ready) || 
                 (is_dma && !dma_ready);
    
    assign cmd_ready = !stall && !rst;

    always @(posedge clk) begin
        if (rst) begin
            halted <= 0;
            core0_start <= 0; core1_start <= 0; dma_start <= 0;
            halt_pending <= 0;
        end else begin
            // Импульсы старта сбрасываются каждый такт
            core0_start <= 0; core1_start <= 0; dma_start <= 0;

            // Handshake: Valid & Ready
            if (cmd_valid && cmd_ready) begin
                case (cmd_data[63:56])
                    CMD_HALT: halt_pending <= 1;
                    CMD_NTT: begin
                        if (cmd_data[55] == 0) core0_start <= 1;
                        else core1_start <= 1;
                    end
                    CMD_DMA: dma_start <= 1; // Восстановлено
                endcase
            end
            
            if (halt_pending && engines_idle) halted <= 1;
        end
    end
endmodule
