`timescale 1ns/1ps
`include "../include/data_type.svh"

module gamma_sum(
    input           clk,
    input           rst,
    // Control Signals
    input           delay_n_valid,   // 來自 delay_n 的 valid
    output reg      gamma_sum_valid, // 輸出給下一級的 valid

    // Data Inputs (Q1.15)
    input  r_t      r_k_in_real,
    input  r_t      r_k_in_imag,
    input  r_t      r_k_minus_N_in_real,
    input  r_t      r_k_minus_N_in_imag,

    // Data Outputs (Q1.15)
    output gamma_t  gamma_out_real,
    output gamma_t  gamma_out_imag
);
    parameter L = 16;
    integer i;

    // ------------------------------------------------------
    // Register Definitions
    // ------------------------------------------------------
    // Shift registers (Delay Line)
    gamma_t delay_line_real[0:L-1];
    gamma_t delay_line_imag[0:L-1];

    // Product (Current term, Q1.15)
    gamma_t product_real;
    gamma_t product_imag;

    // Accumulator (Output Buffer, Q1.15)
    gamma_t gamma_out_real_buf;
    gamma_t gamma_out_imag_buf;

    assign gamma_out_real = gamma_out_real_buf;
    assign gamma_out_imag = gamma_out_imag_buf;

    // ------------------------------------------------------
    // Combinational Logic: Complex Multiplication & Scaling
    // r[k] * conj(r[k-N])
    // Re = Re(k)*Re(k-N) + Im(k)*Im(k-N)
    // Im = Im(k)*Re(k-N) - Re(k)*Im(k-N)
    // Q1.15 * Q1.15 -> Q2.30 -> (>>15) -> Q1.15
    // ------------------------------------------------------
    // 先把 operand 擴成 32-bit signed 比較安全
    logic signed [31:0] re1, im1, re2, im2;
    logic signed [31:0] product_real_full;
    logic signed [31:0] product_imag_full;
    logic signed [31:0] product_real_shift;
    logic signed [31:0] product_imag_shift;

    always_comb begin
        re1 = $signed(r_k_in_real);
        im1 = $signed(r_k_in_imag);
        re2 = $signed(r_k_minus_N_in_real);
        im2 = $signed(r_k_minus_N_in_imag);

        // Q2.30 full precision
        product_real_full = re1 * re2 + im1 * im2;
        product_imag_full = im1 * re2 - re1 * im2;

        // Q2.30 → Q1.15：右移 15 bits
        product_real_shift = product_real_full >>> 20;
        product_imag_shift = product_imag_full >>> 20;

        // 取低 16 bits 當成 gamma_t (Q1.15)
        product_real = product_real_shift[15:0];
        product_imag = product_imag_shift[15:0];
    end

    // ------------------------------------------------------
    // Sequential Logic: Shift Register (Delay Line)
    // ------------------------------------------------------
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            for (i = 0; i < L; i=i+1) begin
                delay_line_real[i] <= '0;
                delay_line_imag[i] <= '0;
            end
        end else begin
            if (delay_n_valid) begin
                for (i = L-1; i > 0; i=i-1) begin
                    delay_line_real[i] <= delay_line_real[i-1];
                    delay_line_imag[i] <= delay_line_imag[i-1];
                end
                delay_line_real[0] <= product_real;
                delay_line_imag[0] <= product_imag;
            end
        end
    end

    // ------------------------------------------------------
    // Sequential Logic: Moving Sum Accumulator & Valid Out
    // S[n] = S[n-1] + new_term - old_term_from_delay_line
    // ------------------------------------------------------
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            gamma_out_real_buf <= '0;
            gamma_out_imag_buf <= '0;
            gamma_sum_valid    <= 1'b0;
        end else begin
            if (delay_n_valid) begin
                gamma_out_real_buf <= gamma_out_real_buf
                                      + product_real
                                      - delay_line_real[L-1];
                gamma_out_imag_buf <= gamma_out_imag_buf
                                      + product_imag
                                      - delay_line_imag[L-1];

                gamma_sum_valid <= 1'b1;
            end else begin
                gamma_sum_valid <= 1'b0;
            end
        end
    end
endmodule

