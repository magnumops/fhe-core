module arbiter_test_shim #(parameter N=4096)(
    input wire clk,
    input wire rst,
    
    input  wire        req_0,
    input  wire        rw_0,
    input  wire [47:0] addr_0,
    input  wire [31:0] len_0,
    output wire        ack_0,
    
    input  wire        req_1,
    input  wire        rw_1,
    input  wire [47:0] addr_1,
    input  wire [31:0] len_1,
    output wire        ack_1
);

    // FIXED: Increased size to 2*N (8192) to match Arbiter's new interface
    localparam MAX_DATA = 2*N; 

    bit [63:0] wdata_0 [0:MAX_DATA-1];
    bit [63:0] rdata_0 [0:MAX_DATA-1];
    bit [63:0] wdata_1 [0:MAX_DATA-1];
    bit [63:0] rdata_1 [0:MAX_DATA-1];

    mem_arbiter #(.N(N), .MAX_DATA(MAX_DATA)) u_arb (
        .clk(clk), .rst(rst),
        
        .req_0(req_0), .rw_0(rw_0), .addr_0(addr_0), .len_0(len_0),
        .wdata_0(wdata_0), .rdata_0(rdata_0), .ack_0(ack_0),
        
        .req_1(req_1), .rw_1(rw_1), .addr_1(addr_1), .len_1(len_1),
        .wdata_1(wdata_1), .rdata_1(rdata_1), .ack_1(ack_1)
    );
    
    export "DPI-C" function set_wdata_0;
    export "DPI-C" function get_rdata_0;
    export "DPI-C" function set_wdata_1;
    export "DPI-C" function get_rdata_1;

    // Functions now handle larger indices if needed, casting to 13 bits (8192)
    function void set_wdata_0(input longint idx, input longint val);
        wdata_0[idx[12:0]] = val;
    endfunction
    
    function longint get_rdata_0(input longint idx);
        return rdata_0[idx[12:0]];
    endfunction

    function void set_wdata_1(input longint idx, input longint val);
        wdata_1[idx[12:0]] = val;
    endfunction

    function longint get_rdata_1(input longint idx);
        return rdata_1[idx[12:0]];
    endfunction

endmodule
