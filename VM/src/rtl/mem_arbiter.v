module mem_arbiter(
    input clk, input rst,
    input req_dma, input we_dma, input [63:0] addr_dma, input [63:0] wdata_dma,
    output reg gnt_dma, output reg valid_dma, output reg [63:0] rdata_dma,
    input req_0, input we_0, input [63:0] addr_0, input [63:0] wdata_0,
    output reg gnt_0, output reg valid_0, output reg [63:0] rdata_0,
    input req_1, input we_1, input [63:0] addr_1, input [63:0] wdata_1,
    output reg gnt_1, output reg valid_1, output reg [63:0] rdata_1,
    output reg mem_req, output reg mem_we, output reg [63:0] mem_addr, output reg [63:0] mem_wdata,
    input mem_valid, input [63:0] mem_rdata
);
    reg [1:0] pending_client;
    wire busy = (pending_client != 0);

    always @(posedge clk) begin
        if (rst) begin
            gnt_dma <= 0; gnt_0 <= 0; gnt_1 <= 0;
            valid_dma <= 0; valid_0 <= 0; valid_1 <= 0;
            mem_req <= 0; pending_client <= 0;
        end else begin
            gnt_dma <= 0; gnt_0 <= 0; gnt_1 <= 0;
            valid_dma <= 0; valid_0 <= 0; valid_1 <= 0;
            mem_req <= 0;

            if (mem_valid) begin
                case (pending_client)
                    1: begin valid_dma <= 1; rdata_dma <= mem_rdata; end
                    2: begin valid_0 <= 1; rdata_0 <= mem_rdata; end
                    3: begin valid_1 <= 1; rdata_1 <= mem_rdata; end
                endcase
                pending_client <= 0;
            end

            // SIMPLE FIXED PRIORITY
            if (!busy && !mem_valid) begin
                if (req_dma) begin
                    mem_req <= 1; mem_we <= we_dma; mem_addr <= addr_dma; mem_wdata <= wdata_dma;
                    gnt_dma <= 1;
                    if (!we_dma) pending_client <= 1;
                end else if (req_0) begin
                    mem_req <= 1; mem_we <= we_0; mem_addr <= addr_0; mem_wdata <= wdata_0;
                    gnt_0 <= 1;
                    if (!we_0) pending_client <= 2;
                end else if (req_1) begin
                    mem_req <= 1; mem_we <= we_1; mem_addr <= addr_1; mem_wdata <= wdata_1;
                    gnt_1 <= 1;
                    if (!we_1) pending_client <= 3;
                end
            end
        end
    end
endmodule
