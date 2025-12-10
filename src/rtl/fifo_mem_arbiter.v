`timescale 1ns / 1ps

module mem_arbiter(
    input clk, input rst,
    // Client DMA
    input req_dma, input we_dma, input [63:0] addr_dma, input [63:0] wdata_dma,
    output gnt_dma, output valid_dma, output [63:0] rdata_dma,
    // Client 0
    input req_0, input we_0, input [63:0] addr_0, input [63:0] wdata_0,
    output gnt_0, output valid_0, output [63:0] rdata_0,
    // Client 1
    input req_1, input we_1, input [63:0] addr_1, input [63:0] wdata_1,
    output gnt_1, output valid_1, output [63:0] rdata_1,
    // Memory Interface
    output reg mem_req, output reg mem_we, output reg [63:0] mem_addr, output reg [63:0] mem_wdata,
    input mem_valid, input [63:0] mem_rdata
);

    // --- Input FIFOs (Request Buffering) ---
    // Payload: {we, addr, wdata} = 1 + 64 + 64 = 129 bits
    localparam PAYLOAD_W = 129;
    
    wire [PAYLOAD_W-1:0] fifo_in_dma = {we_dma, addr_dma, wdata_dma};
    wire [PAYLOAD_W-1:0] fifo_out_dma;
    wire fifo_empty_dma, fifo_full_dma;
    wire fifo_rd_dma;

    sync_fifo #(.WIDTH(PAYLOAD_W), .DEPTH(4)) q_dma (
        .clk(clk), .rst(rst),
        .wr_en(req_dma), .din(fifo_in_dma), .full(fifo_full_dma),
        .rd_en(fifo_rd_dma), .dout(fifo_out_dma), .empty(fifo_empty_dma)
    );
    assign gnt_dma = !fifo_full_dma; // Grant immediately if FIFO not full

    // ... (Repeating for Core 0 and Core 1) ...
    // Since bash heredoc is tricky with repetition, I will use generated signals logic in next step
    // For now let's stick to the current plan: 
    // We need to REPLACE existing mem_arbiter.v with this new logic.
    
    // Instead of full implementation here, I'll stop to verify previous steps.
endmodule
