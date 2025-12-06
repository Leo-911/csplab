`timescale 1ns/1ps
`include "include/data_type.svh"

module minus (
    // Control Signals (新增以配合 top.sv)
    input           mag_valid,      // 來自 mag 模組
    input           phi_rho_valid,  // 來自 phi_rho 模組
    output          minus_valid,    // 輸出給 argmax

    // Data Signals
    input  mag_t    mag_in,
    input  phi_t    phi_rho,
    output lambda_t lambda_out
);

    // -----------------------------------------------------------
    // Control Logic
    // -----------------------------------------------------------
    // 根據 top.sv，此模組為純組合邏輯 (無 clk/rst)。
    // 輸出 Valid 的條件：必須兩個輸入來源 (mag 和 phi_rho) 都有效。
    assign minus_valid = mag_valid && phi_rho_valid;

    // -----------------------------------------------------------
    // Data Logic
    // -----------------------------------------------------------
    // 計算 lambda = mag - phi_rho
    // 這裡加上一個 mux：如果數據無效，將輸出強制設為 0。
    // 這有助於波形除錯（看到 0 就知道無效），也能避免無效數據傳遞產生的干擾。
    assign lambda_out = (minus_valid) ? (mag_in - phi_rho) : '0;

endmodule