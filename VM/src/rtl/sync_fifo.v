`timescale 1ns / 1ps

module sync_fifo #(
    parameter WIDTH = 64,
    parameter DEPTH = 16
)(
    input  wire             clk,
    input  wire             rst,
    input  wire             wr_en,
    input  wire [WIDTH-1:0] din,
    output wire             full,
    input  wire             rd_en,
    output reg  [WIDTH-1:0] dout,
    output wire             empty
);

    localparam PTR_WIDTH = $clog2(DEPTH);
    reg [PTR_WIDTH-1:0] wr_ptr;
    reg [PTR_WIDTH-1:0] rd_ptr;
    reg [PTR_WIDTH:0]   count;
    reg [WIDTH-1:0] mem [0:DEPTH-1];

    assign full  = (count == DEPTH[PTR_WIDTH:0]);
    assign empty = (count == {(PTR_WIDTH+1){1'b0}});

    always @(posedge clk) begin
        if (rst) wr_ptr <= {PTR_WIDTH{1'b0}};
        else if (wr_en && !full) begin
            mem[wr_ptr] <= din;
            wr_ptr <= wr_ptr + 1'b1;
        end
    end

    always @(posedge clk) begin
        if (rst) begin
            rd_ptr <= {PTR_WIDTH{1'b0}};
            dout   <= {WIDTH{1'b0}};
        end else if (rd_en && !empty) begin
            dout <= mem[rd_ptr];
            rd_ptr <= rd_ptr + 1'b1;
        end
    end

    always @(posedge clk) begin
        if (rst) count <= {(PTR_WIDTH+1){1'b0}};
        else begin
            case ({wr_en && !full, rd_en && !empty})
                2'b10: count <= count + 1'b1;
                2'b01: count <= count - 1'b1;
                default: count <= count;
            endcase
        end
    end
endmodule
