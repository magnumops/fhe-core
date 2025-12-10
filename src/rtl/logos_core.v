`timescale 1ns / 1ps

module logos_core(
    input wire clk,
    input wire rst,
    input wire cmd_valid,
    input wire [7:0] cmd_opcode,
    input wire [3:0] cmd_slot,
    input wire [47:0] cmd_dma_addr,
    input wire cmd_target,
    output wire ready
);

    wire mem_req, mem_we;
    wire [47:0] mem_addr;
    wire [63:0] mem_wdata;
    wire [63:0] mem_rdata;
    wire mem_valid;

    mem_arbiter arb_inst (
        .clk(clk), .rst(rst),
        .req(mem_req), .we(mem_we), .addr(mem_addr), .wdata(mem_wdata),
        .valid_dma(mem_valid), .rdata_dma(mem_rdata)
    );

    ntt_engine #( .CORE_ID(0) ) core0 (
        .clk(clk), .rst(rst),
        .cmd_valid(cmd_valid && (cmd_target == 0)), 
        .cmd_opcode(cmd_opcode),
        .cmd_slot(cmd_slot),
        .cmd_dma_addr(cmd_dma_addr),
        .arb_req(mem_req),
        .arb_we(mem_we),
        .arb_addr(mem_addr),
        .arb_wdata(mem_wdata),
        .arb_valid(mem_valid),
        .arb_rdata(mem_rdata),
        .ready(ready)
    );
endmodule
