`timescale 1ns/1ps
`include "../include/data_type.svh"
// 假設裡面有：
// typedef logic signed [15:0] gamma_t; // Q6.10
// typedef logic signed [15:0] mag_t;   // Q6.10

module mag (
    input  logic   clk,
    input  logic   rst,             // active-low, 和 SystemC 版對齊（目前用 posedge rst）
    input  logic   gamma_sum_valid, // 新增：輸入有效
    input  gamma_t gamma_in_real,   // x
    input  gamma_t gamma_in_imag,   // y
    output mag_t   mag_out,         // |x + j y|  ≈ alpha*max + beta*min
    output logic   mag_valid        // 新增：輸出有效
);

    // ------------------------------------------------------------
    // Q 格式說明：
    //  gamma_t, mag_t : signed [15:0]，視為 Q6.10
    //  r              : ratio ≈ min/max，視為 Q0.10 (0 ~ 1)
    //  alpha, beta    : 係數 LUT，視為 Q6.10
    // ------------------------------------------------------------
    localparam int F_GAM   = 10;  // gamma, mag 小數位
    localparam int F_COEF  = 10;  // alpha, beta 小數位
    localparam int F_RATIO = 10;  // ratio 小數位

    // ---------------------------
    // segment threshold (Q0.10)
    // 對應原 SystemC 的 segment[] (tan(k*pi/32))
    // ---------------------------
    localparam logic [15:0] SEG0 = 16'd100; // 25/256  * 1024 ≈ 100
    localparam logic [15:0] SEG1 = 16'd204; // 51/256  * 1024 ≈ 204
    localparam logic [15:0] SEG2 = 16'd312; // 78/256  * 1024 ≈ 312
    localparam logic [15:0] SEG3 = 16'd424; // 106/256 * 1024 ≈ 424
    localparam logic [15:0] SEG4 = 16'd548; // 137/256 * 1024 ≈ 548
    localparam logic [15:0] SEG5 = 16'd720; // 180/256 * 1024 ≈ 720
    localparam logic [15:0] SEG6 = 16'd800; // 200/256 * 1024 ≈ 800
    localparam logic [15:0] SEG7 = 16'd840; // 210/256 * 1024 ≈ 840

    // ---------------------------
    // alpha LUT (Q6.10)
    // 對應 SystemC alpha_lut[] 量化到 *1024
    // ---------------------------
    localparam logic signed [15:0] A0 = 16'sd1230; // 1.201171875 * 1024 ≈ 1230
    localparam logic signed [15:0] A1 = 16'sd1018; // 0.994140625  * 1024 ≈ 1018
    localparam logic signed [15:0] A2 = 16'sd1001; // 0.9775390625 * 1024 ≈ 1001
    localparam logic signed [15:0] A3 = 16'sd974;  // 0.951171875  * 1024 ≈ 974
    localparam logic signed [15:0] A4 = 16'sd938;  // 0.916015625  * 1024 ≈ 938
    localparam logic signed [15:0] A5 = 16'sd895;  // 0.8740234375 * 1024 ≈ 895
    localparam logic signed [15:0] A6 = 16'sd837;  // 0.8173828125 * 1024 ≈ 837
    localparam logic signed [15:0] A7 = 16'sd838;  // 0.818359375  * 1024 ≈ 838
    localparam logic signed [15:0] A8 = 16'sd725;  // 0.7080078125 * 1024 ≈ 725

    // ---------------------------
    // beta LUT (Q6.10)
    // 對應 SystemC beta_lut[] 量化到 *1024
    // ---------------------------
    localparam logic signed [15:0] B0 = 16'sd25;   // 0.0244140625 * 1024 ≈ 25
    localparam logic signed [15:0] B1 = 16'sd126;  // 0.123046875  * 1024 ≈ 126
    localparam logic signed [15:0] B2 = 16'sd225;  // 0.2197265625 * 1024 ≈ 225
    localparam logic signed [15:0] B3 = 16'sd322;  // 0.314453125  * 1024 ≈ 322
    localparam logic signed [15:0] B4 = 16'sd416;  // 0.40625      * 1024 ≈ 416
    localparam logic signed [15:0] B5 = 16'sd505;  // 0.4931640625 * 1024 ≈ 505
    localparam logic signed [15:0] B6 = 16'sd591;  // 0.5771484375 * 1024 ≈ 591
    localparam logic signed [15:0] B7 = 16'sd591;  // same as above
    localparam logic signed [15:0] B8 = 16'sd721;  // 0.7041015625 * 1024 ≈ 721

    // ------------------------------------------------------------
    // 中間訊號宣告
    // ------------------------------------------------------------
    logic signed [15:0] ax, ay;         // |x|, |y|
    logic signed [15:0] max_val, min_val;
    logic       [15:0]  r;             // ratio = (min/max) in Q0.10
    logic signed [15:0] alpha, beta;    // from LUT
    logic signed [31:0] prod_ax, prod_ay, sum_prod;
    mag_t               mag_next;
    logic signed [25:0] num;

    // ------------------------------------------------------------
    // 組合邏輯：計算 mag_next
    // ------------------------------------------------------------
    always_comb begin
        // 1) 絕對值
        ax = gamma_in_real[15] ? -gamma_in_real : gamma_in_real;
        ay = gamma_in_imag[15] ? -gamma_in_imag : gamma_in_imag;

        // 2) ax = max(|x|,|y|), ay = min(|x|,|y|)
        if (ax >= ay) begin
            max_val = ax;
            min_val = ay;
        end else begin
            max_val = ay;
            min_val = ax;
        end

        // 預設值（避免 latch）
        alpha    = '0;
        beta     = '0;
        prod_ax  = '0;
        prod_ay  = '0;
        sum_prod = '0;
        mag_next = '0;
        r        = '0;

        if (max_val == 16'sd0) begin
            // |x|=|y|=0 → 輸出 0
            mag_next = '0;
        end else begin
            // 3) ratio r = min/max，量化成 Q0.10
            //    r ≈ (min * 2^F_RATIO) / max
            num = min_val <<< F_RATIO;
            r   = num / max_val;

            // 4) 根據 r 所在區間選 alpha, beta
            if (r < SEG0) begin
                alpha = A0;  beta = B0;
            end else if (r < SEG1) begin
                alpha = A1;  beta = B1;
            end else if (r < SEG2) begin
                alpha = A2;  beta = B2;
            end else if (r < SEG3) begin
                alpha = A3;  beta = B3;
            end else if (r < SEG4) begin
                alpha = A4;  beta = B4;
            end else if (r < SEG5) begin
                alpha = A5;  beta = B5;
            end else if (r < SEG6) begin
                alpha = A6;  beta = B6;
            end else if (r < SEG7) begin
                alpha = A7;  beta = B7;
            end else begin
                alpha = A8;  beta = B8;
            end

            // 5) z ≈ alpha * max + beta * min
            //    alpha, beta, max, min 都是 Q6.10
            //    → 乘積為 Q12.20，+ 後右移 10 回到 Q6.10
            prod_ax  = alpha * max_val;   // Q12.20
            prod_ay  = beta  * min_val;   // Q12.20
            sum_prod = prod_ax + prod_ay; // Q12.20

            // 右移 10 位回到 Q6.10，wrap overflow 即截斷
            mag_next = sum_prod >>> F_COEF;  // 自動截成 16 bits
        end
    end

    // ------------------------------------------------------------
    // 同步邏輯：1-cycle latency，只有 valid=1 才更新 & 輸出有效
    // ------------------------------------------------------------
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            mag_out  <= '0;
            mag_valid <= 1'b0;
        end else begin
            if (gamma_sum_valid) begin
                // 只有在輸入 valid 的時候才接收並輸出有效
                mag_out  <= mag_next;
                mag_valid <= 1'b1;
            end else begin
                // 沒有新輸入：保持 mag_out、不輸出 valid
                mag_valid <= 1'b0;
            end
        end
    end

endmodule
