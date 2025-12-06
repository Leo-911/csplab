`timescale 1ns/1ps
`include "include/data_type.svh"
module delay_n #(
    parameter N = 256
) (
    input           clk,
    input           rst,
    // Control Signal (符合 top.sv 的命名)
    input           in_valid,
    
    // Data Inputs
    input  r_t      rx_re_in,
    input  r_t      rx_img_in,
    
    // Control Output (符合 top.sv 的命名)
    output reg      delay_n_valid,
    
    // Data Outputs
    output r_t      r_real,
    output r_t      r_imag,
    output r_t      r_dN_real,
    output r_t      r_dN_imag
);

    // 移位暫存器 (Delay Line)
    reg r_t delay_line_real [0:N-1];
    reg r_t delay_line_imag [0:N-1];

    // 輸出緩衝器 (Output Buffers)
    reg r_t r_real_buf;
    reg r_t r_imag_buf;
    reg r_t r_dN_real_buf;
    reg r_t r_dN_imag_buf;

    // 將 Buffer 連接到 Output Ports
    assign r_real    = r_real_buf;
    assign r_imag    = r_imag_buf;
    assign r_dN_real = r_dN_real_buf;
    assign r_dN_imag = r_dN_imag_buf;

    integer i;

    // ----------------------------------------------------------------
    // 主要邏輯：資料移位與輸出更新
    // ----------------------------------------------------------------
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            // 1. 重置輸出 Valid
            delay_n_valid <= 1'b0;
            
            // 2. 重置輸出數據
            r_real_buf    <= 0;
            r_imag_buf    <= 0;
            r_dN_real_buf <= 0;
            r_dN_imag_buf <= 0;

            // 3. 重置 Delay Line
            for (i = 0; i < N; i = i + 1) begin
                delay_line_real[i] <= 0;
                delay_line_imag[i] <= 0;
            end
        end
        else begin
            // ----------------------------------------
            // 只有當輸入有效 (in_valid) 時才執行動作
            // ----------------------------------------
            if (in_valid) begin
                // A. 更新輸出 Valid 訊號 (跟隨數據延遲一拍)
                delay_n_valid <= 1'b1;

                // B. 更新「當前」數據輸出 (r_real/imag) - 延遲 1 cycle
                r_real_buf <= rx_re_in;
                r_imag_buf <= rx_img_in;

                // C. 更新「延遲 N」數據輸出 (r_dN_real/imag)
                // 從 Delay Line 的最後一個位置取出
                r_dN_real_buf <= delay_line_real[N-1];
                r_dN_imag_buf <= delay_line_imag[N-1];

                // D. 執行移位暫存器 (Shift Register) 操作
                for (i = N-1; i > 0; i = i - 1) begin
                    delay_line_real[i] <= delay_line_real[i-1];
                    delay_line_imag[i] <= delay_line_imag[i-1];
                end
                // 將新數據填入 Delay Line 頭部
                delay_line_real[0] <= rx_re_in;
                delay_line_imag[0] <= rx_img_in;
            end
            else begin
                // ----------------------------------------
                // 當輸入無效時 (in_valid = 0)
                // ----------------------------------------
                // 1. 輸出 Valid 拉低，通知後級模組資料無效
                delay_n_valid <= 1'b0;

                // 2. 數據保持不變 (Hold)
                // 移位暫存器不移動，Output Buffer 數值維持原樣
                // 這能確保一旦 valid 恢復，數據流可以無縫接軌
            end
        end
    end

endmodule