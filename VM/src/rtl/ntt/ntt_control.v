module ntt_control #(
    parameter N_LOG = 3,  // Log2(8)
    parameter N     = 8
)(
    input  wire       clk,
    input  wire       rst,
    input  wire       start,
    output reg [N_LOG-1:0]  addr_u,
    output reg [N_LOG-1:0]  addr_v,
    output reg [N_LOG-1:0]  addr_w,
    output reg        valid,
    output reg        done
);

    localparam IDLE  = 0;
    localparam WORK  = 1;
    localparam DONE  = 2;
    
    reg [1:0] state;
    
    // Внутренние счетчики (N_LOG:0)
    reg [N_LOG:0] stage; 
    reg [N_LOG:0] k;     
    reg [N_LOG:0] j;     
    
    reg [N_LOG:0] m;       
    reg [N_LOG:0] half_m;  
    reg [N_LOG:0] w_stride; 

    // Промежуточные сигналы
    wire [N_LOG:0] calc_u = k + j;
    wire [N_LOG:0] calc_v = k + j + half_m;
    wire [N_LOG:0] calc_w = j * w_stride;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= IDLE;
            valid <= 0;
            done  <= 0;
            stage <= 1;
            k <= 0;
            j <= 0;
            m <= 2;
            half_m <= 1;
            w_stride <= N >> 1; 
            addr_u <= 0; addr_v <= 0; addr_w <= 0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    if (start) begin
                        state <= WORK;
                        stage <= 1;
                        k <= 0;
                        j <= 0;
                        m <= 2;
                        half_m <= 1;
                        w_stride <= N >> 1;
                    end
                end

                WORK: begin
                    valid <= 1; // По умолчанию 1, пока мы в WORK
                    
                    addr_u <= calc_u[N_LOG-1:0];
                    addr_v <= calc_v[N_LOG-1:0];
                    addr_w <= calc_w[N_LOG-1:0];

                    if (j < half_m - 1) begin
                        j <= j + 1;
                    end else begin
                        j <= 0;
                        if (k + m < N) begin
                            k <= k + m;
                        end else begin
                            k <= 0;
                            if (stage < N_LOG) begin
                                stage <= stage + 1;
                                m <= m << 1;
                                half_m <= half_m << 1;
                                w_stride <= w_stride >> 1;
                            end else begin
                                // Finish
                                state <= DONE;
                                // FIX: Не сбрасываем valid здесь!
                                // Он останется 1 на этом такте (вместе с последними данными).
                                // В следующем такте state будет DONE, и там valid сбросится.
                            end
                        end
                    end
                end

                DONE: begin
                    valid <= 0; // Вот здесь сбрасываем valid
                    done <= 1;
                    if (!start) state <= IDLE;
                end
            endcase
        end
    end
endmodule
