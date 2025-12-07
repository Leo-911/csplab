`timescale 1ns/1ps
`include "../include/data_type.svh"

// 重命名為 angle_buffer 以避免與 Verilog 關鍵字 'buf' 衝突
module angle_buffer (
    input           clk,
    input           rst,
    // Control Signals
    input           angle_valid,    // 來自 angle 模組
    output reg      buf_valid,      // 輸出給 select_eps

    // Data Signals
    input  ang_t    ang_in,
    
    // Exposed State for select_eps
    // 注意：將整個 Array 輸出會消耗大量佈線資源 (256 * 13 bits)，
    // 但為了實現 select_eps 的平行查找，這是必要的。
    output ang_t    angle_buf [0:255], 
    output reg [7:0] write_ptr
);

    // Internal pointer
    reg [7:0] ptr;
    integer i;

    // --------------------------------------------------
    // Write Pointer Logic
    // --------------------------------------------------
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            ptr <= 0;
        end 
        else begin
            if (angle_valid) begin
                // 寫入後指標 +1 (指向下一個空位)
                ptr <= ptr + 1;
            end
            // Stall: 若 angle_valid = 0，指標保持不變
        end
    end

    // --------------------------------------------------
    // Buffer Memory Logic (Flip-Flop based)
    // --------------------------------------------------
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            for (i = 0; i < 256; i = i + 1) begin
                angle_buf[i] <= 0;
            end
        end 
        else begin
            if (angle_valid) begin
                // 寫入當前數據
                // 注意：這裡是 Non-blocking assignment，使用當前(舊的) ptr 值寫入
                angle_buf[ptr] <= ang_in;
            end
            // Stall: 保持 buffer 內容不變
        end
    end

    // --------------------------------------------------
    // Valid Signal Propagation
    // --------------------------------------------------
    // 這裡產生一個 1-cycle 的延遲，表示「資料已寫入完成，可供讀取」
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            buf_valid <= 1'b0;
        end 
        else begin
            // 由於寫入 Buffer 需要一個 Clock 邊緣，
            // select_eps 需要在下一個 Clock 才能讀到正確的 angle_buf[ptr]，
            // 所以 valid 訊號也順延一拍，剛好對齊。
            buf_valid <= angle_valid;
        end
    end

    // --------------------------------------------------
    // Output Assignment
    // --------------------------------------------------
    // 輸出當前的 write_ptr (注意：這是指向"下一個"寫入位置)
    always @(*) begin
        write_ptr = ptr;
    end

endmodule
