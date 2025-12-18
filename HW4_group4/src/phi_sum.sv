`timescale 1ns/1ps
`include "../include/data_type.svh"

module phi_sum(
    input           clk,
    input           rst,
    // Control Signals
    input           delay_n_valid,  // 控制信號
    output reg      phi_sum_valid,  // 輸出有效信號

    // Data Inputs
    input r_t       r_k_in_real,
    input r_t       r_k_in_imag,
    input r_t       r_k_minus_N_in_real,
    input r_t       r_k_minus_N_in_imag,
    // input rho_t  rho,            // 已移除 rho

    // Data Output
    output phi_t    phi_out
);

parameter L = 16;
integer i;

// Register Definitions
phi_t delay_line [0:L-1];
phi_t energy_to_sum;
phi_t phi_out_buf;

assign phi_out = phi_out_buf;

// ---------- 運算中間變數 ----------
reg signed [32:0] temp_rk_sq;
reg signed [32:0] temp_rkmN_sq;
reg signed [31:0] temp_rk_sq_shift;
reg signed [31:0] temp_rkmN_sq_shift;
reg signed [15:0] r_k_sq;
reg signed [15:0] r_kmN_sq;
// reg signed [31:0] temp_energy; // 已移除 (原本用於存 rho 運算結果)

// -----------------------------------------------------------
// 1. 組合邏輯運算 (計算當前輸入的 Energy)
// -----------------------------------------------------------
always @(*) begin
    // A. 計算平方 (假設輸入 Q1.15 -> 結果 Q2.30)
    temp_rk_sq   =33'( r_k_in_real) * r_k_in_real + 33'(r_k_in_imag) * r_k_in_imag;
    temp_rkmN_sq = 33'(r_k_minus_N_in_real) * r_k_minus_N_in_real +33'( r_k_minus_N_in_imag) * r_k_minus_N_in_imag;

    // B. Scaling (右移 20 位, Q2.30 -> Q2.10)
    // 這裡保留原有的 Scaling，將 32-bit 的平方和縮小回適合累加的大小
    temp_rk_sq_shift   = temp_rk_sq >>> 20;
    temp_rkmN_sq_shift = temp_rkmN_sq >>> 20;

    // C. 截斷 (Truncate) 到 16-bit
    r_k_sq   = temp_rk_sq_shift[15:0];
    r_kmN_sq = temp_rkmN_sq_shift[15:0];

    // D. 計算總和 (直接相加，不再乘以 rho)
    // energy_to_sum = |r_k|^2 + |r_{k-N}|^2
    energy_to_sum = (r_k_sq + r_kmN_sq) >>>1;
end

// -----------------------------------------------------------
// 2. Sequential Logic: Delay Line (Moving Window)
// -----------------------------------------------------------
always @(posedge clk or posedge rst) begin
    if (rst) begin
        for (i = 0; i < L; i = i + 1)
            delay_line[i] <= 0;
    end 
    else begin
        // Pipeline Stall: 只有 valid 時才移動
        if (delay_n_valid) begin
            for (i = L-1; i > 0; i = i - 1)
                delay_line[i] <= delay_line[i-1];
            delay_line[0] <= energy_to_sum;
        end
    end
end   

// -----------------------------------------------------------
// 3. Sequential Logic: Accumulator (Running Sum)
// -----------------------------------------------------------
always @(posedge clk or posedge rst) begin
    if (rst) begin
        phi_out_buf   <= 0;
        phi_sum_valid <= 1'b0;
    end 
    else begin
        if (delay_n_valid) begin
            // 累加器：加上最新的 energy，減去最舊的 energy (Moving Sum)
            phi_out_buf   <= phi_out_buf + energy_to_sum - delay_line[L-1];
            
            // 輸出 Valid
            phi_sum_valid <= 1'b1;
        end 
        else begin
            // Invalid 時保持狀態
            phi_sum_valid <= 1'b0;
        end
    end
end   

endmodule
