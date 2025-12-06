`timescale 1ns/1ps
`include "../include/data_type.svh"

module argmax (
    input  logic    clk,
    input  logic    rst,          // Active-high reset
    input  logic    minus_valid,  // 新增：輸入有效
    input  lambda_t lambda,    // 輸入 lambda
    output theta_t  theta_out,    // 輸出 argmax 的索引
    output logic    argmax_valid  // 新增：輸出有效
);

    // System Constants
    localparam int N            = 256;
    localparam int PIPE_LATENCY = 9; // 1(寫入 buffer) + 8(比較樹 stages)

    // 輸入緩衝區 (Shift Register)，對應 SystemC 的 buf[N]
    // 只有在 minus_valid = 1 時才接收新的 lambda
    lambda_t data_buffer [0:N-1];
    
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            for (int i = 0; i < N; i++) begin
                data_buffer[i] <= 16'sd0; 
            end
        end else if (minus_valid) begin
            // Shift operation: buf[i] = buf[i-1]
            for (int i = N-1; i > 0; i--) begin
                data_buffer[i] <= data_buffer[i-1];
            end
            // Insert new value at head
            data_buffer[0] <= lambda;
        end
        // 若 minus_valid = 0，data_buffer 維持不變
    end

    // 定義 Pipeline Tree 的資料結構
    typedef struct packed {
        lambda_t val;
        theta_t  idx;
    } pair_t;

    pair_t stages [0:8][0:N-1];

    // Stage 0: 初始化層 
    // idx = 255 - pos.
    // data_buffer[0] 是最新的 -> idx = 255
    // data_buffer[255] 是最舊的 -> idx = 0
    always_comb begin
        for (int i = 0; i < N; i++) begin
            stages[0][i].val = data_buffer[i];
            stages[0][i].idx = 8'(255 - i); 
        end
    end

    // Stage 1 ~ 8: Pipelined Comparator Tree
    genvar level, k;
    generate
        for (level = 0; level < 8; level++) begin : pipe_stage
            localparam int num_pairs = N >> (level + 1); 
            
            for (k = 0; k < num_pairs; k++) begin : comp_unit
                always_ff @(posedge clk or posedge rst) begin
                    if (rst) begin
                        // Reset to minimum value and logic 0 index
                        stages[level+1][k].val <=  -16'sd32768; // 16-bit signed 最小值
                        stages[level+1][k].idx <= 8'd0;
                    end else begin
                        // 比較相鄰兩個元素 (2*k 和 2*k+1)
                        if (stages[level][2*k].val >= stages[level][2*k+1].val) begin
                            stages[level+1][k] <= stages[level][2*k];
                        end else begin
                            stages[level+1][k] <= stages[level][2*k+1];
                        end
                    end
                end
            end
        end
    endgenerate

    // 有效位元 pipeline：對齊比較樹的延遲
    logic [PIPE_LATENCY-1:0] valid_pipe;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            valid_pipe <= '0;
        end else begin
            // 往後 shift，一直把 minus_valid 往後送
            valid_pipe <= {valid_pipe[PIPE_LATENCY-2:0], minus_valid};
        end
    end

    assign argmax_valid = valid_pipe[PIPE_LATENCY-1];

    // 輸出結果
    // 經過 8 個 stages + 1 個 buffer 後，stages[8][0] 保存最大值及其索引
    assign theta_out = stages[8][0].idx;

endmodule
