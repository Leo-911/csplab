`timescale 1ns/1ps
`include "include/data_type.svh"

module gamma_sum(
    input           clk,
    input           rst,
    // Control Signals
    input           delay_n_valid,  // 來自 delay_n 的 valid
    output reg      gamma_sum_valid,// 輸出給下一級的 valid

    // Data Inputs
    input  r_t      r_k_in_real,
    input  r_t      r_k_in_imag,
    input  r_t      r_k_minus_N_in_real,
    input  r_t      r_k_minus_N_in_imag,
    
    // Data Outputs
    output gamma_t  gamma_out_real,
    output gamma_t  gamma_out_imag
);

parameter L = 16;
integer i;

// ------------------------------------------------------
// Register Definitions
// ------------------------------------------------------
// Shift registers (Delay Line)
reg gamma_t delay_line_real[0:L-1];
reg gamma_t delay_line_imag[0:L-1];

// Product (Current term)
reg gamma_t product_real;
reg gamma_t product_imag;

// Accumulator (Output Buffer)
reg gamma_t gamma_out_real_buf;
reg gamma_t gamma_out_imag_buf;

assign gamma_out_real = gamma_out_real_buf;
assign gamma_out_imag = gamma_out_imag_buf;

// ------------------------------------------------------
// Combinational Logic: Complex Multiplication & Scaling
// Formula: r[k] * conj(r[k-N])
// Re = Re(k)*Re(k-N) + Im(k)*Im(k-N)
// Im = Im(k)*Re(k-N) - Re(k)*Im(k-N)
// ------------------------------------------------------
reg signed [31:0] product_real_full;
reg signed [31:0] product_imag_full;
reg signed [31:0] product_real_shift; // 修正: 原代碼漏了宣告
reg signed [31:0] product_imag_shift; // 修正: 原代碼漏了宣告

always @(*) begin
    // 1. Full 32-bit multiplication (Q1.15 * Q1.15 -> Q2.30)
    product_real_full = r_k_in_real * r_k_minus_N_in_real + r_k_in_imag * r_k_minus_N_in_imag;
    product_imag_full = r_k_in_imag * r_k_minus_N_in_real - r_k_in_real * r_k_minus_N_in_imag;

    // 2. Right shift to reduce width (Q2.30 -> Q2.10)
    // 注意：這裡的 shift 量決定了動態範圍，需確保不會 overflow
    product_real_shift = product_real_full >>> 20;
    product_imag_shift = product_imag_full >>> 20;

    // 3. Truncate to gamma_t (16-bit)
    // 取 shift 後的低 16 位
    product_real = product_real_shift[15:0];
    product_imag = product_imag_shift[15:0];
end    

// ------------------------------------------------------
// Sequential Logic: Shift Register (Delay Line)
// ------------------------------------------------------
always @(posedge clk or posedge rst) begin
    if (rst) begin
        for (i = 0; i < L; i=i+1) begin
            delay_line_real[i] <= 0;
            delay_line_imag[i] <= 0;
        end
    end 
    else begin
        // Pipeline Stall: 只有輸入有效時才移動
        if (delay_n_valid) begin
            for (i = L-1; i > 0; i=i-1) begin
                delay_line_real[i] <= delay_line_real[i-1];
                delay_line_imag[i] <= delay_line_imag[i-1];
            end
            delay_line_real[0] <= product_real;
            delay_line_imag[0] <= product_imag;
        end
        // Invalid 時保持狀態
    end
end

// ------------------------------------------------------
// Sequential Logic: Moving Sum Accumulator & Valid Out
// S[n] = S[n-1] + new_term - old_term_from_delay_line
// ------------------------------------------------------
always @(posedge clk or posedge rst) begin
    if (rst) begin
        gamma_out_real_buf <= 0;
        gamma_out_imag_buf <= 0;
        gamma_sum_valid    <= 1'b0;
    end 
    else begin
        if (delay_n_valid) begin
            // 更新累加器
            gamma_out_real_buf <= gamma_out_real_buf + product_real - delay_line_real[L-1];
            gamma_out_imag_buf <= gamma_out_imag_buf + product_imag - delay_line_imag[L-1];
            
            // 輸出 Valid 拉高
            gamma_sum_valid <= 1'b1;
        end 
        else begin
            // 輸入無效時，累加器保持不變，Valid 拉低
            gamma_sum_valid <= 1'b0;
        end
    end
end

endmodule