`timescale 1ns / 1ps

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
    // DPI Import
    import "DPI-C" function void dpi_exec_alu(input int opcode, input int slot, input int count);

    localparam S_IDLE=0, S_DMA_READ=1, S_DMA_WRITE=2, S_CALC=3, S_DONE=4;
    reg [2:0] state;
    
    reg [63:0] mem [0:4095];
    
    // Counters
    reg [12:0] dma_req_idx;
    reg [12:0] dma_ack_idx;
    reg [12:0] dma_len;
    reg [47:0] current_dma_addr;
    
    // FIX: Регистр для сохранения Opcode и Slot
    reg [7:0] latched_opcode;
    reg [3:0] latched_slot;

    // Opcode definitions
    localparam OP_LOAD   = 8'h02;
    localparam OP_STORE  = 8'h04;
    localparam OP_NTT    = 8'h05;
    localparam OP_INTT   = 8'h06;
    localparam OP_MULT   = 8'h07;

    always @(posedge clk) begin
        if (rst) begin
            state <= S_IDLE;
            ready <= 1;
            arb_req <= 0;
            arb_we <= 0;
            dma_req_idx <= 0;
            dma_ack_idx <= 0;
            dma_len <= 0;
            current_dma_addr <= 0;
            arb_addr <= 0;
            arb_wdata <= 0;
            latched_opcode <= 0;
        end else begin
            case (state)
                S_IDLE: begin
                    ready <= 1;
                    if (cmd_valid) begin
                        ready <= 0;
                        current_dma_addr <= cmd_dma_addr;
                        
                        // FIX: Запоминаем команду
                        latched_opcode <= cmd_opcode;
                        latched_slot <= cmd_slot;
                        
                        // DMA Init
                        dma_ack_idx <= 0;
                        dma_req_idx <= 1; 
                        
                        if (cmd_opcode == OP_LOAD) begin
                            state <= S_DMA_READ;
                            dma_len <= 13'd4096;
                            arb_req <= 1;
                            arb_we <= 0;
                            arb_addr <= cmd_dma_addr;
                        end 
                        else if (cmd_opcode == OP_STORE) begin
                            state <= S_DMA_WRITE;
                            dma_len <= 13'd4096;
                            arb_req <= 0;
                            dma_req_idx <= 0;
                        end
                        else if (cmd_opcode == OP_NTT || cmd_opcode == OP_INTT || cmd_opcode == OP_MULT) begin
                            state <= S_CALC;
                        end
                        else begin
                            state <= S_DONE;
                        end
                    end
                end

                S_DMA_READ: begin
                    if (dma_req_idx < dma_len) begin
                        arb_req <= 1;
                        arb_addr <= current_dma_addr + 48'({35'b0, dma_req_idx} * 64'd8);
                        dma_req_idx <= dma_req_idx + 13'd1;
                    end else begin
                        arb_req <= 0;
                    end

                    if (arb_valid) begin
                         mem[dma_ack_idx[11:0]] <= arb_rdata;
                         dma_ack_idx <= dma_ack_idx + 13'd1;
                         if (dma_ack_idx == dma_len - 13'd1) state <= S_DONE;
                    end
                end

                S_DMA_WRITE: begin
                    arb_req <= 1;
                    arb_we <= 1;
                    arb_addr <= current_dma_addr + 48'({35'b0, dma_req_idx} * 64'd8);
                    arb_wdata <= mem[dma_req_idx[11:0]];
                    dma_req_idx <= dma_req_idx + 13'd1;

                    if (dma_req_idx == dma_len - 13'd1) begin
                        state <= S_DONE;
                        arb_req <= 0;
                        arb_we <= 0;
                    end
                end

                S_CALC: begin
                    // FIX: Используем latched_opcode вместо cmd_opcode
                    dpi_exec_alu({24'b0, latched_opcode}, {28'b0, latched_slot}, 4096);
                    state <= S_DONE;
                end

                S_DONE: begin
                    ready <= 1;
                    state <= S_IDLE;
                end
            endcase
        end
    end
endmodule
