module command_processor(
    input clk, input rst,
    input cmd_valid, input [63:0] cmd_data,
    output wire cmd_ready,
    output reg core0_start, output reg core1_start,
    input core0_ready, input core1_ready,
    output reg halted
);
    localparam CMD_HALT = 8'h00;

    // Bit 48 selects the core: 0 -> Core0, 1 -> Core1
    wire target_c0 = (cmd_data[48] == 0);
    wire target_c1 = (cmd_data[48] == 1);

    // Stall if the TARGET device is busy
    wire stall = (target_c0 && !core0_ready) || (target_c1 && !core1_ready);

    assign cmd_ready = !stall && !rst;

    always @(posedge clk) begin
        if (rst) begin
            halted <= 0;
            core0_start <= 0; core1_start <= 0;
        end else begin
            core0_start <= 0; 
            core1_start <= 0;
            if (cmd_valid && cmd_ready) begin
                if (cmd_data[63:56] == CMD_HALT) begin
                    halted <= 1;
                end else begin
                    if (target_c0) core0_start <= 1;
                    else           core1_start <= 1;
                end
            end
        end
    end
endmodule
