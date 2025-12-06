module hazard_unit(
    input start_req_0, input start_req_1,
    input [3:0] bank_mask_0, input [3:0] bank_mask_1,
    input busy_0, input busy_1,
    output reg grant_start_0, output reg grant_start_1
);
    always @(*) begin
        grant_start_0 = start_req_0;
        grant_start_1 = start_req_1;
        // Priority: Core 0 wins collision
        if (start_req_0 && start_req_1) grant_start_1 = 0; 
    end
endmodule
