`timescale 1ns/1ps
`include "../include/data_type.svh"
`include "delay_n.sv"
`include "phi_sum.sv"
`include "gamma_sum.sv"
`include "phi_rho.sv"
`include "minus.sv"
`include "angle.sv"
`include "mag.sv"
`include "argmax.sv"
`include "buf.sv"
`include "select_eps.sv"

module top#(
    parameter INT_BITS = 1,  
    parameter FRAC_BITS = 15,
    parameter RHO_INT_BITS = 1,
    parameter RHO_FRAC_BITS = 7
) (
    input  clk,
    input  rst,
    input  in_valid,
    input  signed  [INT_BITS+FRAC_BITS-1:0] rx_re_in,
    input  signed  [INT_BITS+FRAC_BITS-1:0] rx_img_in,
    input  [RHO_INT_BITS+RHO_FRAC_BITS-1:0] rho,
    output [7:0]   theta,
    output [20:0]   epsilon,
    output out_valid
);

// delay_n output
wire r_t r_real;
wire r_t r_imag;
wire r_t r_dN_real;
wire r_t r_dN_imag;
wire delay_n_valid;

// phi_sum output
wire phi_t phi_out;
wire phi_sum_valid;

// gamma_sum output
wire gamma_t gamma_out_real;
wire gamma_t gamma_out_imag;
wire gamma_sum_valid;

// phi_rho output
wire phi_t phi_rho;
wire phi_rho_valid;

// mag output
wire mag_t mag_out;
wire mag_valid;

// angle output
wire ang_t ang_out;
wire angle_valid;

// minus output
wire lambda_t lambda_out;
wire minus_valid;

// argmax output
wire theta_t  theta_out;
wire argmax_valid;

// select_eps output
wire eps_t  eps_out;
wire select_eps_valid;

// buf output
wire ang_t angle_buf [255:0];
wire [7:0] write_ptr  ;
wire buf_valid;

// ---- 計算拉高 out_valid 的時機 ----
parameter N = 256;
parameter L = 16;

// 一個 OFDM symbol 需要的有效資料數量：2N + L
localparam int BLOCK_LEN = 2*N + L;  // 這裡是 528

// 計數器：需要能表示到 BLOCK_LEN
reg [$clog2(BLOCK_LEN):0] valid_cnt;
reg                       out_valid_r;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        valid_cnt   <= '0;
        out_valid_r <= 1'b0;
    end else begin
        // 預設 out_valid_r 為 0（除非剛好數到 BLOCK_LEN-1）
        out_valid_r <= 1'b0;

        if (select_eps_valid) begin
            if (valid_cnt == BLOCK_LEN-1) begin
                // 第 BLOCK_LEN 次 valid：拉高 out_valid 一個 clock，並清除計數
                out_valid_r <= 1'b1;
                valid_cnt   <= '0;
            end else begin
                // 其他次數：只累加
                valid_cnt <= valid_cnt + 1'b1;
            end
        end
        // 如果這個 cycle select_eps_valid = 0，就不動作（維持原本的 valid_cnt）
    end
end

assign out_valid = out_valid_r;


assign theta = theta_out;
assign epsilon = eps_out;

delay_n u_delay_n(
    .clk(clk),
    .rst(rst),
    .in_valid(in_valid),    //in
    .rx_re_in(rx_re_in),
    .rx_img_in(rx_img_in),
    .delay_n_valid(delay_n_valid),  //out
    .r_real(r_real),
    .r_imag(r_imag),
    .r_dN_real(r_dN_real),
    .r_dN_imag(r_dN_imag)
);

phi_sum u_phi_sum(
    .clk(clk),
    .rst(rst),
    .delay_n_valid(delay_n_valid),  //in
    .r_k_in_real(r_real),
    .r_k_in_imag(r_imag),
    .r_k_minus_N_in_real(r_dN_real),
    .r_k_minus_N_in_imag(r_dN_imag),
    .phi_sum_valid(phi_sum_valid),  //out
    .phi_out(phi_out)
);

gamma_sum u_gamma_sum(
    .clk(clk),
    .rst(rst),
    .delay_n_valid(delay_n_valid),  //in
    .r_k_in_real(r_real),
    .r_k_in_imag(r_imag),
    .r_k_minus_N_in_real(r_dN_real),
    .r_k_minus_N_in_imag(r_dN_imag),
    .gamma_sum_valid(gamma_sum_valid),  //out
    .gamma_out_real(gamma_out_real),
    .gamma_out_imag(gamma_out_imag)
);

phi_rho u_phi_rho(
    .clk(clk),
    .rst(rst),
    .phi_in(phi_out),   
    .phi_sum_valid(phi_sum_valid),  //in
    .rho_in(rho),
    .phi_rho_valid(phi_rho_valid),  //out
    .phi_rho(phi_rho)
);

minus u_minus(
    .mag_in(mag_out),
    .mag_valid(mag_valid),  //in
    .phi_rho(phi_rho),
    .phi_rho_valid(phi_rho_valid),  //in
    .minus_valid(minus_valid),  //out
    .lambda_out(lambda_out)
);

angle u_angle(
    .clk(clk),
    .rst(rst),
    .gamma_sum_valid(gamma_sum_valid),  //in
    .gamma_in_real(gamma_out_real),
    .gamma_in_imag(gamma_out_imag),
    .angle_valid(angle_valid),  //out
    .ang_out(ang_out)
);

mag u_mag(
    .clk(clk),
    .rst(rst),
    .gamma_sum_valid(gamma_sum_valid),  //in
    .gamma_in_real(gamma_out_real),
    .gamma_in_imag(gamma_out_imag),
    .mag_valid(mag_valid),  //out
    .mag_out(mag_out)
);

argmax u_argmax(
    .clk(clk),
    .rst(rst),
    .minus_valid(minus_valid),  //in
    .lambda(lambda_out),
    .argmax_valid(argmax_valid),    //out
    .theta_out(theta_out)
);

buff u_buf(
    .clk(clk),
    .rst(rst),
    .angle_valid(angle_valid),  //in
    .ang_in(ang_out),
    .buf_valid(buf_valid),  //out
    .angle_buf(angle_buf),
    .write_ptr(write_ptr)
);

select_eps u_select_eps(
    .angle_buf(angle_buf),
    .write_ptr(write_ptr),
    .buf_valid(buf_valid),  //in
    .theta_in(theta_out),
    .argmax_valid(argmax_valid), //in
    .select_eps_valid(select_eps_valid), //out
    .eps_out(eps_out)
);

endmodule
