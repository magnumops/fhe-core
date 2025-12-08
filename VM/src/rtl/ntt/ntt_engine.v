module ntt_engine #(
    parameter CORE_ID = 0,
    parameter N_LOG = 12
)(
    input wire clk, input wire rst,
    input wire cmd_valid, input wire [7:0] cmd_opcode,
    input wire [3:0] cmd_slot, input wire [47:0] cmd_dma_addr,
    output reg ready,
    output reg arb_req, output reg arb_we, output reg [47:0] arb_addr,
    output reg [63:0] arb_wdata, input wire arb_valid, input wire [63:0] arb_rdata
);

    localparam S_IDLE=0, S_DMA_READ=1, S_DMA_WRITE=2, S_CALC=3, S_DONE=4;
    reg [2:0] state;
    reg [63:0] q, mu;
    reg [63:0] mem [0:4095];
    
    // Два независимых счетчика для конвейера
    reg [12:0] dma_req_idx; // Счетчик отправленных запросов
    reg [12:0] dma_ack_idx; // Счетчик полученных данных
    reg [12:0] dma_len;
    reg [47:0] current_dma_addr;

    always @(posedge clk) begin
        if (rst) begin
            state <= S_IDLE;
            ready <= 1;
            arb_req <= 0;
            arb_we <= 0;
            dma_req_idx <= 0;
            dma_ack_idx <= 0;
        end else begin
            case (state)
                S_IDLE: begin
                    ready <= 1;
                    if (cmd_valid) begin
                        ready <= 0;
                        current_dma_addr <= cmd_dma_addr;
                        
                        // Сброс счетчиков
                        dma_ack_idx <= 0;
                        // Начинаем запрашивать СРАЗУ с 1-го элемента (0-й выставляем ниже)
                        dma_req_idx <= 1; 
                        
                        // Предварительная установка адреса для 0-го элемента
                        arb_req <= 1;
                        arb_addr <= cmd_dma_addr;

                        if (cmd_opcode == 8'h01) begin // LOAD_CONFIG
                            state <= S_DMA_READ; dma_len <= 3; arb_we <= 0;
                        end 
                        else if (cmd_opcode == 8'h02) begin // LOAD_DATA
                            state <= S_DMA_READ; dma_len <= 4096; arb_we <= 0;
                        end 
                        else if (cmd_opcode == 8'h04) begin // STORE_DATA
                            state <= S_DMA_WRITE; dma_len <= 4096;
                            arb_we <= 1;
                            arb_wdata <= mem[0];
                            // Для Store логика проще (req_idx = ack_idx)
                            dma_req_idx <= 0; 
                        end
                        else begin
                            arb_req <= 0;
                            state <= S_DONE;
                        end
                    end
                end

                S_DMA_READ: begin
                    // --- 1. Request Stream (Pipelined Address Gen) ---
                    // Мы продолжаем выставлять адреса каждый такт, не дожидаясь данных
                    if (dma_req_idx < dma_len) begin
                        arb_req <= 1;
                        // Next Address = Base + ReqIdx * 8
                        arb_addr <= current_dma_addr + {32'b0, dma_req_idx} * 64'd8;
                        dma_req_idx <= dma_req_idx + 1;
                    end else begin
                        // Мы запросили всё, снимаем req
                        arb_req <= 0; 
                    end

                    // --- 2. Acknowledge Stream (Data Capture) ---
                    // Данные приходят с задержкой, ловим их независимо
                    if (arb_valid) begin
                         if (dma_len == 3) begin
                            if (dma_ack_idx == 0) q <= arb_rdata;
                            if (dma_ack_idx == 1) mu <= arb_rdata;
                         end else begin
                            mem[dma_ack_idx[11:0]] <= arb_rdata;
                            // Debug (первые 3 слова)
                            if (dma_ack_idx < 3) 
                                $display("[RTL] READ ACK Idx=%d Val=%h", dma_ack_idx, arb_rdata);
                         end
                         
                         dma_ack_idx <= dma_ack_idx + 1;
                         
                         // Выход, когда ПОЛУЧИЛИ все данные
                         if (dma_ack_idx == dma_len - 1) begin
                             state <= S_DONE;
                             $display("[RTL] READ FINISHED. Total Words: %d", dma_len);
                         end
                    end
                end

                S_DMA_WRITE: begin
                    // Для записи используем dma_req_idx как основной счетчик
                    // Выставляем данные на шину
                    
                    // Адрес для СЛЕДУЮЩЕГО такта
                    arb_addr <= current_dma_addr + {32'b0, (dma_req_idx + 1'b1)} * 64'd8;
                    // Данные для СЛЕДУЮЩЕГО такта
                    arb_wdata <= mem[(dma_req_idx + 1'b1) & 13'hFFF];
                    
                    dma_req_idx <= dma_req_idx + 1;

                    if (dma_req_idx == dma_len - 1) begin
                        state <= S_DONE; arb_req <= 0; arb_we <= 0;
                        $display("[RTL] STORE FINISHED.");
                    end
                end

                S_DONE: begin ready <= 1; state <= S_IDLE; end
            endcase
        end
    end
endmodule
