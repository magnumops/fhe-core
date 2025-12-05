module mem_arbiter(
    input clk, input rst,
    
    // Port DMA (Highest Priority)
    input req_dma, input we_dma, input [63:0] addr_dma, input [63:0] wdata_dma,
    output reg gnt_dma, output reg valid_dma, output reg [63:0] rdata_dma,

    // Port 0 (Core 0)
    input req_0, input we_0, input [63:0] addr_0, input [63:0] wdata_0,
    output reg gnt_0, output reg valid_0, output reg [63:0] rdata_0,
    
    // Port 1 (Core 1)
    input req_1, input we_1, input [63:0] addr_1, input [63:0] wdata_1,
    output reg gnt_1, output reg valid_1, output reg [63:0] rdata_1,
    
    // Physical Memory
    output reg mem_req, output reg mem_we, output reg [63:0] mem_addr, output reg [63:0] mem_wdata,
    input mem_valid, input [63:0] mem_rdata
);
    // State to track who is currently waiting for data
    reg [1:0] pending_client; // 0: None, 1: DMA, 2: C0, 3: C1

    always @(posedge clk) begin
        if (rst) begin
            gnt_dma <= 0; gnt_0 <= 0; gnt_1 <= 0;
            valid_dma <= 0; valid_0 <= 0; valid_1 <= 0;
            mem_req <= 0;
            pending_client <= 0;
        end else begin
            // Pulse resets
            gnt_dma <= 0; gnt_0 <= 0; gnt_1 <= 0;
            valid_dma <= 0; valid_0 <= 0; valid_1 <= 0;
            mem_req <= 0;

            // --- Priority Logic: DMA > Core 0 > Core 1 ---
            if (req_dma) begin
                mem_req <= 1; mem_we <= we_dma; mem_addr <= addr_dma; mem_wdata <= wdata_dma;
                gnt_dma <= 1;
                if (!we_dma) pending_client <= 1; // Expecting read data
            end else if (req_0) begin
                mem_req <= 1; mem_we <= we_0; mem_addr <= addr_0; mem_wdata <= wdata_0;
                gnt_0 <= 1;
                if (!we_0) pending_client <= 2;
            end else if (req_1) begin
                mem_req <= 1; mem_we <= we_1; mem_addr <= addr_1; mem_wdata <= wdata_1;
                gnt_1 <= 1;
                if (!we_1) pending_client <= 3;
            end
            
            // --- Response Routing ---
            if (mem_valid) begin
                case (pending_client)
                    1: begin valid_dma <= 1; rdata_dma <= mem_rdata; end
                    2: begin valid_0 <= 1; rdata_0 <= mem_rdata; end
                    3: begin valid_1 <= 1; rdata_1 <= mem_rdata; end
                endcase
                pending_client <= 0; // Reset pending
            end
        end
    end
endmodule
