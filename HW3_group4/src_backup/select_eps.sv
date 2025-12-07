`timescale 1ns/1ps
`include "../include/data_type.svh"

// 純組合電路，讀 buffer 計算 eps
module select_eps (
    // Data Inputs
    input  ang_t          angle_buf [0:255], // 來自 angle_buffer
    input  logic   [7:0]  write_ptr,         // 來自 angle_buffer
    input  theta_t        theta_in,          // 來自 argmax
    
    // Control Inputs
    input  logic          buf_valid,         // 來自 angle_buffer
    input  logic          argmax_valid,      // 來自 argmax

    // Outputs
    output eps_t          eps_out,
    output reg            select_eps_valid   // 輸出給 top (控制 out_valid)
);

    // ------------------------------------------------------------
    // Parameters
    // ------------------------------------------------------------
    // 1/(2*pi) ≈ 0.1591549
    // 您原本設定 4189。假設這是經過系統驗證的常數，維持不變。
    // 注意：為了正確的 signed 乘法，這裡建議顯式宣告為 signed 或在運算時 cast
    localparam signed [19:0] INV_TWO_PI = 20'sd4189; 

    // ------------------------------------------------------------
    // Internal Signals
    // ------------------------------------------------------------
    logic [7:0]         read_ptr;
    logic signed [32:0] mult_result;

    // ------------------------------------------------------------
    // Combinational Logic
    // ------------------------------------------------------------
    always @(*) begin
        // 1. Calculate Read Pointer
        // write_ptr 指向"下一個空位"，所以最新資料在 write_ptr - 1
        // theta_in = 255 (最新) -> 應讀取 write_ptr - 1
        // theta_in = 0   (最舊) -> 應讀取 write_ptr - 1 - 255 = write_ptr
        // 公式簡化為: read_ptr = write_ptr + theta_in (利用 8-bit overflow 特性)
        read_ptr = write_ptr + theta_in;

        // 2. Logic & Valid Generation
        if (buf_valid && argmax_valid) begin
            // 執行乘法：ang_t (Q3.10) * INV (Q?)
            mult_result = angle_buf[read_ptr] * INV_TWO_PI;
            
            // 截斷輸出
            // 原代碼 mult_result[24:4] -> 21 bits
            eps_out = mult_result[24:4];
            
            select_eps_valid = 1'b1;
        end 
        else begin
            mult_result      = '0;
            eps_out          = '0;
            select_eps_valid = 1'b0;
        end
    end

endmodule
