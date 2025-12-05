module logos_core(
    input clk, input rst,
    input cmd_valid, input [63:0] cmd_data, output cmd_ready, output halted,
    // NEW: Debug Ports
    output [63:0] perf_ops_0,
    output [63:0] perf_ops_1
);
    wire c0_start, c1_start, dma_start;
    wire c0_ready, c1_ready, dma_ready; 
    wire dma_busy; assign dma_ready = !dma_busy;
    wire grant_0, grant_1; 
    
    // Memory Wires
    wire m0_req, m0_we, m0_gnt, m0_valid; wire [63:0] m0_addr, m0_wdata, m0_rdata;
    wire m1_req, m1_we, m1_gnt, m1_valid; wire [63:0] m1_addr, m1_wdata, m1_rdata;
    wire dma_req, dma_we, dma_gnt, dma_valid; wire [63:0] dma_addr, dma_wdata, dma_rdata;
    wire phy_req, phy_we, phy_valid; wire [63:0] phy_addr, phy_wdata, phy_rdata;

    command_processor cp_inst (
        .clk(clk), .rst(rst),
        .cmd_valid(cmd_valid), .cmd_data(cmd_data), .cmd_ready(cmd_ready),
        .core0_start(c0_start), .core1_start(c1_start), .dma_start(dma_start),
        .core0_ready(c0_ready), .core1_ready(c1_ready), .dma_ready(dma_ready),
        .halted(halted)
    );

    hazard_unit hu_inst (
        .start_req_0(c0_start), .start_req_1(c1_start),
        .bank_mask_0(4'b0001), .bank_mask_1(4'b0010),
        .busy_0(!c0_ready), .busy_1(!c1_ready),
        .grant_start_0(grant_0), .grant_start_1(grant_1)
    );

    mem_arbiter arb_inst (
        .clk(clk), .rst(rst),
        .req_dma(dma_req), .we_dma(dma_we), .addr_dma(dma_addr), .wdata_dma(dma_wdata),
        .gnt_dma(dma_gnt), .valid_dma(dma_valid), .rdata_dma(dma_rdata),
        .req_0(m0_req), .we_0(m0_we), .addr_0(m0_addr), .wdata_0(m0_wdata),
        .gnt_0(m0_gnt), .valid_0(m0_valid), .rdata_0(m0_rdata),
        .req_1(m1_req), .we_1(m1_we), .addr_1(m1_addr), .wdata_1(m1_wdata),
        .gnt_1(m1_gnt), .valid_1(m1_valid), .rdata_1(m1_rdata),
        .mem_req(phy_req), .mem_we(phy_we), .mem_addr(phy_addr), .mem_wdata(phy_wdata),
        .mem_valid(phy_valid), .mem_rdata(phy_rdata)
    );
    
    dpi_mem_wrapper mem_inst (
        .clk(clk), .req(phy_req), .we(phy_we), .addr(phy_addr), .wdata(phy_wdata),
        .valid(phy_valid), .rdata(phy_rdata)
    );

    ntt_core #(.CORE_ID(0)) core0 (
        .clk(clk), .rst(rst), .start(grant_0), .ready(c0_ready),
        .mem_req(m0_req), .mem_we(m0_we), .mem_addr(m0_addr), .mem_wdata(m0_wdata),
        .mem_gnt(m0_gnt), .mem_valid(m0_valid), .mem_rdata(m0_rdata),
        .op_count(perf_ops_0) // <--- CONNECTED
    );

    ntt_core #(.CORE_ID(1)) core1 (
        .clk(clk), .rst(rst), .start(grant_1), .ready(c1_ready),
        .mem_req(m1_req), .mem_we(m1_we), .mem_addr(m1_addr), .mem_wdata(m1_wdata),
        .mem_gnt(m1_gnt), .mem_valid(m1_valid), .mem_rdata(m1_rdata),
        .op_count(perf_ops_1) // <--- CONNECTED
    );
    
    dma_unit dma_inst (
        .clk(clk), .rst(rst),
        .start(dma_start), .base_addr(64'h1000), .busy(dma_busy),
        .mem_req(dma_req), .mem_we(dma_we), .mem_addr(dma_addr), .mem_wdata(dma_wdata),
        .mem_gnt(dma_gnt)
    );
endmodule
