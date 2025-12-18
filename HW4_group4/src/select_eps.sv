`timescale 1ns/1ps
`include "../include/data_type.svh"

// 純組合：把輸入 ang (Q3.10) 轉成 eps (Q1.20) = ang / (2*pi)
module select_eps (
    input  ang_t  ang_in,          // 從 argmax 出來的 angle (Q3.10)
    input  logic  argmax_valid,    // 這一拍的 ang_in 是否有效

    output eps_t  eps_out,         // Q1.20
    output logic  select_eps_valid // eps_out 是否有效
);
    // 1/(2*pi) ≈ 0.159154...，這裡用 Q13 量化 -> 20-bit
    localparam logic [19:0] INV_TWO_PI = 20'd1311;  // Q0.13 / Q13 fixed-point

    // ang_t (13bit, Q3.10) × INV_TWO_PI (20bit, Q0.13)
    // => Q3.23，用 33 bits 裝
    logic signed [32:0] mult_result;

    always_comb begin
        // 預設
        mult_result      = '0;
        eps_out          = '0;
        select_eps_valid = 1'b0;

        if (argmax_valid) begin
            mult_result = $signed(ang_in) * $signed(INV_TWO_PI);
            // Q3.23 -> Q1.20，右移 3 bits（保留低 21 bits 給 eps_t）
            eps_out          = mult_result >>> 3;
            select_eps_valid = 1'b1;
        end
    end
endmodule

