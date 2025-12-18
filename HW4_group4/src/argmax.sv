`timescale 1ns/1ps
`include "../include/data_type.svh"

module argmax (
    input  logic    clk,
    input  logic    rst,          // Active-high reset

    // 有效資料
    input  logic    minus_valid,  // 這拍的 lambda / ang_in 是否有效
    input  lambda_t lambda,       // lambda(k)
    input  ang_t    ang_in,       // 對應的 angle(k)

    // 輸出：一個 window (256 筆) 的最大值資訊
    output theta_t  theta_out,    // 0~255，window 內的 index
    output ang_t    angle_out,    // 該 index 對應的 angle
    output logic    argmax_valid  // 這拍輸出的 theta_out / angle_out 有效
);
    // -----------------------------
    // 常數
    // -----------------------------
    localparam int N            = 256;
    localparam int L            = 16;
    localparam int WARMUP       = N + L-1;   // 前 N+L 筆不進 window
    localparam int PIPE_LATENCY = 8;       // 比較樹有 8 層 FF

    // -----------------------------
    // 1) 暖機計數：前 N+L 筆 lambda 只計數，不進 window
    // -----------------------------
    logic [15:0] warmup_cnt;
    logic        warmup_done;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            warmup_cnt  <= 16'd0;
            warmup_done <= 1'b0;
        end else if (!warmup_done && minus_valid) begin
            if (warmup_cnt == WARMUP-1)
                warmup_done <= 1'b1;  // 下一拍開始才把資料視為 window 的一員
            else
                warmup_cnt <= warmup_cnt + 16'd1;
        end
    end

    // 這一拍的 sample 要不要進 window
    logic use_sample;
    assign use_sample = minus_valid && warmup_done;

    // -----------------------------
    // 2) 輸入緩衝區：保存最近 256 筆 lambda / angle
    // -----------------------------
    lambda_t lambda_buf [0:N-1];
    lambda_t best_lambda;
    ang_t    angle_buf  [0:N-1];

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            for (int i = 0; i < N; i++) begin
                lambda_buf[i] <= '0;
                angle_buf[i]  <= '0;
            end
        end else if (use_sample) begin
            // shift：buf[i] = buf[i-1]
            for (int i = N-1; i > 0; i--) begin
                lambda_buf[i] <= lambda_buf[i-1];
                angle_buf[i]  <= angle_buf[i-1];
            end
            // 最新的樣本塞在 index 0
            lambda_buf[0] <= lambda;
            angle_buf[0]  <= ang_in;
        end
    end

    // -----------------------------
    // 3) 比較樹的資料結構：lambda + index + angle
    // -----------------------------
    typedef struct packed {
        lambda_t val;
        theta_t  idx;
        ang_t    ang;
    } pair_t;

    pair_t stages [0:8][0:N-1];

    // Stage 0：初始化，各 buffer 位置映射成 index
    // lambda_buf[0] = 最新 → idx = 255
    // lambda_buf[255] = 最舊 → idx = 0
    always_comb begin
        for (int i = 0; i < N; i++) begin
            stages[0][i].val = lambda_buf[i];
            stages[0][i].idx = theta_t'(8'(N-1 - i));
            stages[0][i].ang = angle_buf[i];
        end
    end

    // -----------------------------
    // 4) Stage 1~8：pipelined comparator tree
    // -----------------------------
    genvar level, k;
    generate
        for (level = 0; level < 8; level++) begin : pipe_stage
            localparam int num_pairs = N >> (level + 1);

            for (k = 0; k < num_pairs; k++) begin : comp_unit
                always_ff @(posedge clk or posedge rst) begin
                    if (rst) begin
                        stages[level+1][k].val <= -16'sd32768;
                        stages[level+1][k].idx <= 8'd0;
                        stages[level+1][k].ang <= '0;
                    end else begin
                        if (stages[level][2*k].val >= stages[level][2*k+1].val)
                            stages[level+1][k] <= stages[level][2*k];
                        else
                            stages[level+1][k] <= stages[level][2*k+1];
                    end
                end
            end
        end
    endgenerate

    // -----------------------------
    // 5) Window 計數：每 256 筆做一次 argmax
    // -----------------------------
    logic [7:0] sample_idx, sample_idx_next;
    logic       window_pulse, window_pulse_next;

    // comb：算下一拍 sample_idx / window_pulse
    always_comb begin
        sample_idx_next   = sample_idx;
        window_pulse_next = 1'b0;

        if (use_sample) begin
            if (sample_idx == 8'd255) begin
                // 這一拍是 window 的第 256 筆
                window_pulse_next = 1'b1;
                sample_idx_next   = 8'd0;
            end else begin
                sample_idx_next   = sample_idx + 8'd1;
            end
        end
    end

    // seq：鎖存 sample_idx / window_pulse
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
    // 6) valid pipeline：對齊 8 層比較樹的延遲
    // -----------------------------
    logic [PIPE_LATENCY-1:0] valid_pipe;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            valid_pipe <= '0;
        end else begin
            valid_pipe <= {valid_pipe[PIPE_LATENCY-2:0], window_pulse};
        end
    end

    assign argmax_valid = valid_pipe[PIPE_LATENCY-1];

    // -----------------------------
    // 7) 輸出：stages[8][0] 保留這個 window 的最大 lambda 與對應角度
    // -----------------------------
    assign theta_out = stages[8][0].idx;
    assign angle_out = stages[8][0].ang;
    assign best_lambda    = stages[8][0].val;

endmodule

