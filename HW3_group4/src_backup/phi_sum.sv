`timescale 1ns/1ps
`include "../include/data_type.svh"
module phi_sum(
    input           clk,
    input           rst,
    input           delay_n_valid,
    output reg      phi_sum_valid,

    input r_t       r_k_in_real,
    input r_t       r_k_in_imag,
    input r_t       r_k_minus_N_in_real,
    input r_t       r_k_minus_N_in_imag,
    
    output phi_t    phi_out
);

    parameter L = 16;
    integer i;

    // 使用 typedef 定義的型別
    phi_t delay_line [0:L-1];
    phi_t energy_to_sum;
    phi_t phi_out_buf;

    assign phi_out = phi_out_buf;

    // 中間變數 (需大於 16-bit 以防溢位，維持使用 logic signed [31:0])
    logic signed [31:0] temp_rk_sq;
    logic signed [31:0] temp_rkmN_sq;
    logic signed [31:0] temp_rk_sq_shift;
    logic signed [31:0] temp_rkmN_sq_shift;
    
    // 截斷後暫存 (配合 energy_to_sum 計算)
    logic signed [15:0] r_k_sq;
    logic signed [15:0] r_kmN_sq;

    always @(*) begin
        // Q1.15 * Q1.15 -> Q2.30
        temp_rk_sq   = r_k_in_real * r_k_in_real + r_k_in_imag * r_k_in_imag;
        temp_rkmN_sq = r_k_minus_N_in_real * r_k_minus_N_in_real + r_k_minus_N_in_imag * r_k_minus_N_in_imag;

        // Q2.30 >>> 20 -> Q2.10
        temp_rk_sq_shift   = temp_rk_sq >>> 20;
        temp_rkmN_sq_shift = temp_rkmN_sq >>> 20;

        // Truncate to 16-bit
        r_k_sq   = temp_rk_sq_shift[15:0];
        r_kmN_sq = temp_rkmN_sq_shift[15:0];

        // Sum (Result fits in phi_t if input is not consistently full-scale)
        energy_to_sum = r_k_sq + r_kmN_sq;
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            phi_sum_valid <= 1'b0;
            phi_out_buf   <= '0;
            for (i = 0; i < L; i = i + 1)
                delay_line[i] <= '0;
        end 
        else begin
            if (delay_n_valid) begin
                phi_sum_valid <= 1'b1;
                // Moving Sum
                phi_out_buf   <= phi_out_buf + energy_to_sum - delay_line[L-1];
                
                for (i = L-1; i > 0; i = i - 1)
                    delay_line[i] <= delay_line[i-1];
                delay_line[0] <= energy_to_sum;
            end
            else begin
                phi_sum_valid <= 1'b0;
            end
        end
    end   
endmodule
