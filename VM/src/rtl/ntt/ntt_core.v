module ntt_core #(parameter CORE_ID = 0)(
    input clk, input rst, input start, output reg ready,
    // Memory Port
    output reg mem_req, output reg mem_we, output reg [63:0] mem_addr, output reg [63:0] mem_wdata,
    input mem_gnt, input mem_valid, input [63:0] mem_rdata,
    // NEW: Debug Counter
    output reg [63:0] op_count
);
    reg [2:0] state;
    // 0: IDLE, 1: REQ_READ, 2: WAIT_READ, 3: REQ_WRITE, 4: WAIT_WRITE, 5: DONE

    always @(posedge clk) begin
        if (rst) begin
            state <= 0; ready <= 1; mem_req <= 0; op_count <= 0;
        end else begin
            case (state)
                0: begin // IDLE
                    ready <= 1;
                    if (start) begin
                        state <= 1; ready <= 0;
                        $display("[CORE %0d] Start Task", CORE_ID);
                    end
                end
                1: begin // REQ_READ
                    mem_req <= 1; mem_we <= 0; 
                    mem_addr <= (CORE_ID * 100); 
                    state <= 2;
                end
                2: begin // WAIT_READ
                    if (mem_gnt) begin
                        mem_req <= 0; state <= 3;
                    end
                end
                3: begin // REQ_WRITE
                    mem_req <= 1; mem_we <= 1;
                    mem_addr <= (CORE_ID * 100) + 8;
                    mem_wdata <= 64'hDEADBEEF;
                    state <= 4;
                end
                4: begin // WAIT_WRITE
                    if (mem_gnt) begin
                        mem_req <= 0; state <= 5;
                    end
                end
                5: begin // DONE
                    ready <= 1;
                    op_count <= op_count + 1; // INCREMENT!
                    state <= 0;
                    $display("[CORE %0d] Finished. Total Ops: %0d", CORE_ID, op_count + 1);
                end
            endcase
        end
    end
endmodule
