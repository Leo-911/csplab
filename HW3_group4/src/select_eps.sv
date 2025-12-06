
`timescale 1ns/1ps
`include "../include/data_type.svh"

// 純組合電路，讀 buffer 計算 eps
module select_eps (
    input  ang_t          angle_buf [0:255],
    input  logic   [7:0]  write_ptr,
    input  logic          buf_valid,       // 新增：buf 的 valid
    input  theta_t        theta_in,
    input  logic          argmax_valid,    // 新增：argmax 的 valid
    output eps_t          eps_out,
    output logic          select_eps_valid // 新增：本 module 的 valid
);

    // 常數：1/(2*pi) ≈ 0.15915494309189533577
    localparam logic [19:0] INV_TWO_PI = 20'd4189;  // Q13 fixed-point

    logic [7:0]                  read_ptr;
    logic signed [32:0]          mult_result;

    always_comb begin
        // 預設值（避免 latch）
        select_eps_valid = 1'b0;
        eps_out          = '0;
        mult_result      = '0;

        // 讀取位置先一律算好（不影響正確性）
        read_ptr = (write_ptr - (8'd255 - theta_in)) & 8'hFF;

        // 只有兩個 valid 都為 1 時，才真正計算並拉高 select_eps_valid
        if (buf_valid && argmax_valid) begin
            mult_result      = angle_buf[read_ptr] * INV_TWO_PI;
            eps_out          = mult_result[24:4];   // 選擇 fixed-point slice
            select_eps_valid = 1'b1;
        end
    end

endmodule
