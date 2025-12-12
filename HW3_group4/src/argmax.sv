`timescale 1ns/1ps
`include "../include/data_type.svh"

module argmax (
    input  logic    clk,
    input  logic    rst,          // Active-high reset
    input  logic    minus_valid,  // 輸入 lambda 有效
    input  lambda_t lambda,       // 輸入 lambda
    output theta_t  theta_out,    // argmax 的索引
    output logic    argmax_valid  // 輸出有效
);
    // System Constants
    localparam int N            = 256;
    localparam int L            = 16;
    localparam int WARMUP       = N + L;    // 前 N+L 筆不算 window
    localparam int PIPE_LATENCY = 9;        // 1(寫入 buffer) + 8(比較樹 stages)

    // -----------------------------
    // 暖機計數：前 N+L 個 minus_valid 只計數，不進 window
    // -----------------------------
    logic [15:0] warmup_cnt;
    logic        warmup_done;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            warmup_cnt  <= 16'd0;
            warmup_done <= 1'b0;
        end else begin
            if (!warmup_done && minus_valid) begin
                if (warmup_cnt == WARMUP-1) begin
                    warmup_done <= 1'b1;     // 下一筆開始才是真正 window 第 0 筆
                end else begin
                    warmup_cnt <= warmup_cnt + 16'd1;
                end
            end
        end
    end

    // -----------------------------
    // 輸入緩衝區 (Shift Register)，只在暖機後接收 lambda
    // -----------------------------
    lambda_t data_buffer [0:N-1];
    lambda_t best_lambda;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            for (int i = 0; i < N; i++) begin
                data_buffer[i] <= 16'sd0; 
            end
        end else if (minus_valid &&  (warmup_done || (warmup_cnt == WARMUP-1)) ) begin
            // 暖機完成後，才真正把 lambda 放進 window
            for (int i = N-1; i > 0; i--) begin
                data_buffer[i] <= data_buffer[i-1];
            end
            data_buffer[0] <= lambda;
        end
        // 若 minus_valid = 0 或 暖機未完成，data_buffer 維持不變
    end

    // -----------------------------
    // Stage 0: 初始化層
    // idx = 255 - pos
    // data_buffer[0] 是最新的 -> idx = 255
    // data_buffer[255] 是最舊的 -> idx = 0
    // -----------------------------
    typedef struct packed {
        lambda_t val;
        theta_t  idx;
    } pair_t;

    pair_t stages [0:8][0:N-1];

    always_comb begin
        for (int i = 0; i < N; i++) begin
            stages[0][i].val = data_buffer[i];
            stages[0][i].idx = theta_t'(8'(255 - i)); 
        end
    end

    // -----------------------------
    // Stage 1 ~ 8: Pipelined Comparator Tree
    // -----------------------------
    genvar level, k;
    generate
        for (level = 0; level < 8; level++) begin : pipe_stage
            localparam int num_pairs = N >> (level + 1); 
            
            for (k = 0; k < num_pairs; k++) begin : comp_unit
                always_ff @(posedge clk or posedge rst) begin
                    if (rst) begin
                        stages[level+1][k].val <= -16'sd32768; // 16-bit signed 最小值
                        stages[level+1][k].idx <= 8'd0;
                    end else begin
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

    // -----------------------------
    // Window 計數：暖機之後，每 256 筆 lambda 算一次 argmax
    // 希望在「數到 255 的那一拍」產生 window_pulse
    // -----------------------------
    logic [7:0] sample_idx, sample_idx_next;
    logic       window_pulse, window_pulse_next;  // 給 valid_pipe 的輸入脈衝

    //---------------------
    // comb：算下一拍的狀態
    //---------------------
    always_comb begin
        sample_idx_next   = sample_idx;
        window_pulse_next = 1'b0;

        if (minus_valid && warmup_done) begin
            if (sample_idx == 8'd255) begin
            // 這一拍吃到的這筆 lambda = window 最後一筆
                window_pulse_next = 1'b1;   // ✅ 同一拍拉高
                sample_idx_next   = 8'd0;   // 下個 window 從 0 開始
            end else begin
                sample_idx_next   = sample_idx + 8'd1;
            end
        end
    end

    //---------------------
    // seq：在 clk 邊緣更新
    //---------------------
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            sample_idx   <= 8'd0;
            window_pulse <= 1'b0;
        end else begin
            sample_idx   <= sample_idx_next;
            window_pulse <= window_pulse_next;
        end
    end

    // -----------------------------
    // 有效位元 pipeline：對齊比較樹的延遲
    // - 把 "window_pulse" 往後 shift 9 拍
    // - 當 window_pulse 在 sample_idx==255 那拍為 1 時，
    //   過了 PIPE_LATENCY 拍 argmax_valid 才會對應到那個 window 的結果
    // -----------------------------
    logic [PIPE_LATENCY-1:0] valid_pipe;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            valid_pipe <= '0;
        end else begin
            valid_pipe <= {valid_pipe[PIPE_LATENCY-2:0], window_pulse_next};
        // 用windowpulese會慢一拍
        end
    end

    assign argmax_valid = valid_pipe[PIPE_LATENCY-1];

    // -----------------------------
    // 輸出結果：stages[8][0] 保存 argmax 及其索引
    // -----------------------------
    assign theta_out = stages[8][0].idx;
    assign best_lambda = stages[8][0].val;

endmodule

