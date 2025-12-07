`timescale 1ns/1ps
`include "../include/data_type.svh"

module minus (
    input           mag_valid,
    input           phi_rho_valid,
    output          minus_valid,

    input  mag_t    mag_in,
    input  phi_t    phi_rho,
    output lambda_t lambda_out
);

    // 純組合邏輯
    // Valid 判斷：兩路數據都到齊
    assign minus_valid = mag_valid && phi_rho_valid;

    // 計算 lambda = mag - phi_rho
    // 輸出保護：無效時輸出 0
    assign lambda_out = (minus_valid) ? (mag_in - phi_rho) : '0;

endmodule
