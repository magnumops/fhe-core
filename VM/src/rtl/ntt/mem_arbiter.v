module mem_arbiter #(
    parameter N = 4096,
    parameter MAX_DATA = 8192 // Support Twiddle Factors load
)(
    input  wire clk,
    input  wire rst,

    // Client 0
    input  wire        req_0,
    input  wire        rw_0,
    input  wire [47:0] addr_0,
    input  wire [31:0] len_0,
    input  bit [63:0]  wdata_0 [0:MAX_DATA-1], 
    output bit [63:0]  rdata_0 [0:MAX_DATA-1],
    output reg         ack_0,

    // Client 1
    input  wire        req_1,
    input  wire        rw_1,
    input  wire [47:0] addr_1,
    input  wire [31:0] len_1,
    input  bit [63:0]  wdata_1 [0:MAX_DATA-1],
    output bit [63:0]  rdata_1 [0:MAX_DATA-1],
    output reg         ack_1
);

    import "DPI-C" function void dpi_read_burst(input longint addr, input int len, output bit [63:0] data []);
    import "DPI-C" function void dpi_write_burst(input longint addr, input int len, input bit [63:0] data []);

    localparam S_IDLE = 0;
    localparam S_SERV_0 = 1;
    localparam S_SERV_1 = 2;
    
    reg [1:0] state;
    reg last_serviced; 

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= S_IDLE;
            ack_0 <= 0;
            ack_1 <= 0;
            last_serviced <= 1; 
        end else begin
            ack_0 <= 0;
            ack_1 <= 0;

            case (state)
                S_IDLE: begin
                    if (req_0 && req_1) begin
                        if (last_serviced == 1) state <= S_SERV_0;
                        else state <= S_SERV_1;
                    end else if (req_0) begin
                        state <= S_SERV_0;
                    end else if (req_1) begin
                        state <= S_SERV_1;
                    end
                end

                S_SERV_0: begin
                    if (rw_0 == 0) dpi_read_burst({16'b0, addr_0}, len_0, rdata_0);
                    else           dpi_write_burst({16'b0, addr_0}, len_0, wdata_0);
                    ack_0 <= 1;
                    last_serviced <= 0;
                    state <= S_IDLE;
                end

                S_SERV_1: begin
                    if (rw_1 == 0) dpi_read_burst({16'b0, addr_1}, len_1, rdata_1);
                    else           dpi_write_burst({16'b0, addr_1}, len_1, wdata_1);
                    ack_1 <= 1;
                    last_serviced <= 1;
                    state <= S_IDLE;
                end
            endcase
        end
    end
endmodule
