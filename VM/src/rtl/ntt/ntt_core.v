module ntt_core #(parameter CORE_ID = 0)(
    input clk, input rst, 
    input start, input [63:0] cmd_data, output ready,
    output mem_req, output mem_we, output [63:0] mem_addr, output [63:0] mem_wdata,
    input mem_gnt, input mem_valid, input [63:0] mem_rdata,
    output [63:0] op_count
);
    wire [7:0]  opcode = cmd_data[63:56];
    wire [3:0]  slot   = cmd_data[55:52];
    wire [47:0] dma_addr = cmd_data[47:0];
    
    ntt_engine #(.CORE_ID(CORE_ID)) engine_inst (
        .clk(clk), .rst(rst),
        .cmd_valid(start),      
        .cmd_opcode(opcode),
        .cmd_slot(slot),
        .cmd_dma_addr(dma_addr),
        .ready(ready),
        // RNS Config removed (Internal)
        .arb_req(mem_req), .arb_we(mem_we), .arb_addr(mem_addr[47:0]), .arb_wdata(mem_wdata),
        .arb_gnt(mem_gnt), .arb_valid(mem_valid), .arb_rdata(mem_rdata),
        .dbg_state(),
        .perf_counter_out(op_count)
    );
endmodule
