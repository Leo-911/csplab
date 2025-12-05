`timescale 1ns/1ps
`include "metric_precalc.sv"
`include "metric_summation.sv"
`include "argmax_tracking.sv"

module top #(
    parameter INT_BITS = 1,  
    parameter FRAC_BITS = 15,
    parameter RHO_INT_BITS = 1,
    parameter RHO_FRAC_BITS = 7
) (
    input  clk,
    input  rst,
    input  in_valid,
    input  signed [INT_BITS+FRAC_BITS-1:0] rx_re_in,
    input  signed [INT_BITS+FRAC_BITS-1:0] rx_img_in,
    input  [RHO_INT_BITS+RHO_FRAC_BITS-1:0] rho, 
    
    output [7:0]   theta,
    output [20:0]  epsilon,
    output out_valid
);

    localparam int WL_IN      = INT_BITS + FRAC_BITS;
    localparam int WL_RHO     = RHO_INT_BITS + RHO_FRAC_BITS;
    localparam int FFT_SIZE   = 256;
    localparam int CP_LEN     = 16;
    localparam int WL_METRIC  = 20;
    localparam int WL_SUM     = 24;
    localparam int WL_THETA   = 8;
    localparam int WL_EPS     = 21;

    // Interconnects
    logic stg1_valid;
    logic signed [WL_METRIC-1:0] stg1_corr_r, stg1_corr_i, stg1_energy;
    
    logic stg2_valid;
    logic signed [WL_SUM-1:0] stg2_sum_r, stg2_sum_i, stg2_sum_e;

    logic signed [WL_THETA-1:0] theta_int;
    logic signed [WL_EPS-1:0]   epsilon_int;
    
    // ★★★ 新增：接收 ArgMax 完成訊號 ★★★
    logic argmax_done; 

    // Instantiation
    metric_precalc #(
        .WL_IN(WL_IN), .WL_RHO(WL_RHO), .WL_OUT(WL_METRIC), .FFT_SIZE(FFT_SIZE)
    ) u_precalc (
        .clk(clk), .rst(rst),
        .in_valid(in_valid),
        .r_real_in(rx_re_in), .r_imag_in(rx_img_in), .rho_in(rho),
        .out_valid(stg1_valid),
        .corr_real_out(stg1_corr_r), .corr_imag_out(stg1_corr_i), .energy_out(stg1_energy)
    );

    metric_summation #(
        .WL_IN(WL_METRIC), .WL_OUT(WL_SUM), .L(CP_LEN)
    ) u_summation (
        .clk(clk), .rst(rst),
        .in_valid(stg1_valid), 
        .corr_real_in(stg1_corr_r), .corr_imag_in(stg1_corr_i), .energy_in(stg1_energy),
        .out_valid(stg2_valid),
        .sum_corr_real(stg2_sum_r), .sum_corr_imag(stg2_sum_i), .sum_energy(stg2_sum_e)
    );

    localparam int WL_ARGMAX_IN = 18;
    argmax_tracking #(
        .WL_IN(WL_ARGMAX_IN), .WL_OUT_THETA(WL_THETA), .WL_OUT_EPS(WL_EPS)
    ) u_argmax (
        .clk(clk), .rst(rst),
        .in_valid(stg2_valid), 
        
        // ★★★ Bit Slicing (截斷低位) ★★★
        .sum_r_in(stg2_sum_r[WL_SUM-1 -: WL_ARGMAX_IN]), 
        .sum_i_in(stg2_sum_i[WL_SUM-1 -: WL_ARGMAX_IN]), 
        .sum_e_in(stg2_sum_e[WL_SUM-1 -: WL_ARGMAX_IN]),
        
        .start_search(1'b0),
        .search_done(argmax_done), 
        .theta_est(theta_int),
        .epsilon_est(epsilon_int)
    );
    
    assign theta = theta_int;
    assign epsilon = epsilon_int;
    
    // ★★★ 關鍵修正：輸出改接 argmax_done ★★★
    assign out_valid = argmax_done;

endmodule