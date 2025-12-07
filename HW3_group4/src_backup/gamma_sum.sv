`timescale 1ns/1ps
`include "../include/data_type.svh"

module gamma_sum(
    input           clk,
    input           rst,
    input           delay_n_valid,
    output reg      gamma_sum_valid,

    input  r_t      r_k_in_real,
    input  r_t      r_k_in_imag,
    input  r_t      r_k_minus_N_in_real,
    input  r_t      r_k_minus_N_in_imag,
    
    output gamma_t  gamma_out_real,
    output gamma_t  gamma_out_imag
);

    parameter L = 16;
    integer i;

    // 使用 gamma_t
    gamma_t delay_line_real[0:L-1];
    gamma_t delay_line_imag[0:L-1];

    gamma_t product_real;
    gamma_t product_imag;

    gamma_t gamma_out_real_buf;
    gamma_t gamma_out_imag_buf;

    assign gamma_out_real = gamma_out_real_buf;
    assign gamma_out_imag = gamma_out_imag_buf;

    // 32-bit 中間變數
    logic signed [31:0] product_real_full;
    logic signed [31:0] product_imag_full;
    logic signed [31:0] product_real_shift;
    logic signed [31:0] product_imag_shift;

    always @(*) begin
        // Complex Multiply: r[k] * conj(r[k-N])
        product_real_full = r_k_in_real * r_k_minus_N_in_real + r_k_in_imag * r_k_minus_N_in_imag;
        product_imag_full = r_k_in_imag * r_k_minus_N_in_real - r_k_in_real * r_k_minus_N_in_imag;

        // Scaling (Q2.30 -> Q2.10)
        product_real_shift = product_real_full >>> 20;
        product_imag_shift = product_imag_full >>> 20;

        // Truncate to gamma_t
        product_real = product_real_shift[15:0];
        product_imag = product_imag_shift[15:0];
    end    

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            gamma_sum_valid    <= 1'b0;
            gamma_out_real_buf <= '0;
            gamma_out_imag_buf <= '0;
            for (i = 0; i < L; i=i+1) begin
                delay_line_real[i] <= '0;
                delay_line_imag[i] <= '0;
            end
        end 
        else begin
            if (delay_n_valid) begin
                gamma_sum_valid <= 1'b1;
                
                // Moving Sum Update
                gamma_out_real_buf <= gamma_out_real_buf + product_real - delay_line_real[L-1];
                gamma_out_imag_buf <= gamma_out_imag_buf + product_imag - delay_line_imag[L-1];
                
                // Delay Line Update
                for (i = L-1; i > 0; i=i-1) begin
                    delay_line_real[i] <= delay_line_real[i-1];
                    delay_line_imag[i] <= delay_line_imag[i-1];
                end
                delay_line_real[0] <= product_real;
                delay_line_imag[0] <= product_imag;
            end
            else begin
                gamma_sum_valid <= 1'b0;
            end
        end
    end
endmodule
