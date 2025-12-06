`timescale 1ns / 1ps

module mem_arbiter(
    input clk, input rst,
    
    // Client DMA
    input req_dma, input we_dma, input [63:0] addr_dma, input [63:0] wdata_dma,
    output gnt_dma, output reg valid_dma, output reg [63:0] rdata_dma,
    
    // Client Core 0
    input req_0, input we_0, input [63:0] addr_0, input [63:0] wdata_0,
    output gnt_0, output reg valid_0, output reg [63:0] rdata_0,
    
    // Client Core 1
    input req_1, input we_1, input [63:0] addr_1, input [63:0] wdata_1,
    output gnt_1, output reg valid_1, output reg [63:0] rdata_1,
    
    // Memory Interface
    output reg mem_req, output reg mem_we, output reg [63:0] mem_addr, output reg [63:0] mem_wdata,
    input mem_valid, input [63:0] mem_rdata
);

    // =========================================================================
    // 1. INPUT FIFOs (Request Buffering)
    // Payload: {we, addr, wdata} = 1 + 64 + 64 = 129 bits
    // =========================================================================
    localparam PAYLOAD_W = 129;
    
    // --- DMA FIFO ---
    wire [PAYLOAD_W-1:0] dma_din = {we_dma, addr_dma, wdata_dma};
    wire [PAYLOAD_W-1:0] dma_dout;
    wire dma_empty, dma_full;
    reg  dma_pop;
    
    sync_fifo #(.WIDTH(PAYLOAD_W), .DEPTH(4)) fifo_dma (
        .clk(clk), .rst(rst),
        .wr_en(req_dma), .din(dma_din), .full(dma_full),
        .rd_en(dma_pop), .dout(dma_dout), .empty(dma_empty)
    );
    assign gnt_dma = !dma_full; // Grant if we have space

    // --- Core 0 FIFO ---
    wire [PAYLOAD_W-1:0] c0_din = {we_0, addr_0, wdata_0};
    wire [PAYLOAD_W-1:0] c0_dout;
    wire c0_empty, c0_full;
    reg  c0_pop;
    
    sync_fifo #(.WIDTH(PAYLOAD_W), .DEPTH(4)) fifo_c0 (
        .clk(clk), .rst(rst),
        .wr_en(req_0), .din(c0_din), .full(c0_full),
        .rd_en(c0_pop), .dout(c0_dout), .empty(c0_empty)
    );
    assign gnt_0 = !c0_full;

    // --- Core 1 FIFO ---
    wire [PAYLOAD_W-1:0] c1_din = {we_1, addr_1, wdata_1};
    wire [PAYLOAD_W-1:0] c1_dout;
    wire c1_empty, c1_full;
    reg  c1_pop;
    
    sync_fifo #(.WIDTH(PAYLOAD_W), .DEPTH(4)) fifo_c1 (
        .clk(clk), .rst(rst),
        .wr_en(req_1), .din(c1_din), .full(c1_full),
        .rd_en(c1_pop), .dout(c1_dout), .empty(c1_empty)
    );
    assign gnt_1 = !c1_full;

    // =========================================================================
    // 2. TICKET FIFO (Response Routing)
    // Stores which client made the request: 1=DMA, 2=C0, 3=C1
    // =========================================================================
    reg  [1:0] ticket_in;
    wire [1:0] ticket_out;
    reg  ticket_push;
    wire ticket_pop; // Popped when mem_valid arrives
    wire ticket_full, ticket_empty;
    
    // Depth 32 to allow many pending requests (pipelining)
    sync_fifo #(.WIDTH(2), .DEPTH(32)) ticket_fifo (
        .clk(clk), .rst(rst),
        .wr_en(ticket_push), .din(ticket_in), .full(ticket_full),
        .rd_en(ticket_pop), .dout(ticket_out), .empty(ticket_empty)
    );

    // =========================================================================
    // 3. ARBITRATION LOGIC (Round Robin)
    // =========================================================================
    reg [1:0] rr_turn; // 0, 1, 2
    
    // Unpacking FIFO outputs
    wire dma_we_out, c0_we_out, c1_we_out;
    wire [63:0] dma_addr_out, c0_addr_out, c1_addr_out;
    wire [63:0] dma_wdata_out, c0_wdata_out, c1_wdata_out;
    
    assign {dma_we_out, dma_addr_out, dma_wdata_out} = dma_dout;
    assign {c0_we_out, c0_addr_out, c0_wdata_out}    = c0_dout;
    assign {c1_we_out, c1_addr_out, c1_wdata_out}    = c1_dout;

    always @(posedge clk) begin
        if (rst) begin
            rr_turn <= 0;
            mem_req <= 0;
            mem_we  <= 0;
            mem_addr <= 0;
            mem_wdata <= 0;
            dma_pop <= 0; c0_pop <= 0; c1_pop <= 0;
            ticket_push <= 0;
            ticket_in <= 0;
        end else begin
            // Defaults
            mem_req <= 0;
            dma_pop <= 0; c0_pop <= 0; c1_pop <= 0;
            ticket_push <= 0;
            
            // Can we send a request to memory?
            // Need: Ticket FIFO not full (to store ID) AND Memory ready (assumed always ready for now if no backpressure from mem)
            if (!ticket_full) begin
                // Simple Round Robin Selection
                case (rr_turn)
                    0: begin // Try DMA -> C0 -> C1
                        if (!dma_empty) begin
                            dma_pop <= 1; rr_turn <= 1;
                            mem_req <= 1; mem_we <= dma_we_out; mem_addr <= dma_addr_out; mem_wdata <= dma_wdata_out;
                            ticket_push <= 1; ticket_in <= 2'd1;
                        end else if (!c0_empty) begin
                            c0_pop <= 1; rr_turn <= 2;
                            mem_req <= 1; mem_we <= c0_we_out; mem_addr <= c0_addr_out; mem_wdata <= c0_wdata_out;
                            ticket_push <= 1; ticket_in <= 2'd2;
                        end else if (!c1_empty) begin
                            c1_pop <= 1; rr_turn <= 0;
                            mem_req <= 1; mem_we <= c1_we_out; mem_addr <= c1_addr_out; mem_wdata <= c1_wdata_out;
                            ticket_push <= 1; ticket_in <= 2'd3;
                        end
                    end
                    1: begin // Try C0 -> C1 -> DMA
                        if (!c0_empty) begin
                            c0_pop <= 1; rr_turn <= 2;
                            mem_req <= 1; mem_we <= c0_we_out; mem_addr <= c0_addr_out; mem_wdata <= c0_wdata_out;
                            ticket_push <= 1; ticket_in <= 2'd2;
                        end else if (!c1_empty) begin
                            c1_pop <= 1; rr_turn <= 0;
                            mem_req <= 1; mem_we <= c1_we_out; mem_addr <= c1_addr_out; mem_wdata <= c1_wdata_out;
                            ticket_push <= 1; ticket_in <= 2'd3;
                        end else if (!dma_empty) begin
                            dma_pop <= 1; rr_turn <= 1;
                            mem_req <= 1; mem_we <= dma_we_out; mem_addr <= dma_addr_out; mem_wdata <= dma_wdata_out;
                            ticket_push <= 1; ticket_in <= 2'd1;
                        end
                    end
                    2: begin // Try C1 -> DMA -> C0
                        if (!c1_empty) begin
                            c1_pop <= 1; rr_turn <= 0;
                            mem_req <= 1; mem_we <= c1_we_out; mem_addr <= c1_addr_out; mem_wdata <= c1_wdata_out;
                            ticket_push <= 1; ticket_in <= 2'd3;
                        end else if (!dma_empty) begin
                            dma_pop <= 1; rr_turn <= 1;
                            mem_req <= 1; mem_we <= dma_we_out; mem_addr <= dma_addr_out; mem_wdata <= dma_wdata_out;
                            ticket_push <= 1; ticket_in <= 2'd1;
                        end else if (!c0_empty) begin
                            c0_pop <= 1; rr_turn <= 2;
                            mem_req <= 1; mem_we <= c0_we_out; mem_addr <= c0_addr_out; mem_wdata <= c0_wdata_out;
                            ticket_push <= 1; ticket_in <= 2'd2;
                        end
                    end
                endcase
            end
        end
    end

    // =========================================================================
    // 4. RESPONSE ROUTING
    // =========================================================================
    // If memory returns valid data, we pop the ticket and route
    assign ticket_pop = mem_valid;
    
    always @(*) begin
        valid_dma = 0; rdata_dma = 64'b0;
        valid_0   = 0; rdata_0   = 64'b0;
        valid_1   = 0; rdata_1   = 64'b0;
        
        if (mem_valid && !ticket_empty) begin
            case (ticket_out)
                2'd1: begin valid_dma = 1; rdata_dma = mem_rdata; end
                2'd2: begin valid_0   = 1; rdata_0   = mem_rdata; end
                2'd3: begin valid_1   = 1; rdata_1   = mem_rdata; end
                default: ;
            endcase
        end
    end

endmodule
