`timescale 1ns/1ps
`include "include/data_type.svh"

// 循環 buffer，保存最近 256 個角度
module buf (
    input  logic        clk,
    input  logic        rst,          // active-high reset
    input  logic        angle_valid,  // 新增：輸入有效
    input  ang_t        ang_in,
    output ang_t        angle_buf [0:255], // expose buffer 給 select_eps
    output logic [7:0]  write_ptr,    // expose 寫指標給 select_eps
    output logic        buf_valid     // 新增：輸出有效
);

    logic [7:0] ptr;

    // --------------------------------------------------
    // 寫入指標：只有 angle_valid 時才前進
    // --------------------------------------------------
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            ptr <= 8'd0;
        end else if (angle_valid) begin
            ptr <= ptr + 1'b1;
        end
        // angle_valid = 0 -> ptr 保持不變
    end

    // --------------------------------------------------
    // 寫入 buffer：只有 angle_valid 時才寫
    // --------------------------------------------------
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            integer i;
            for (i = 0; i < 256; i = i + 1)
                angle_buf[i] <= '0;
        end else if (angle_valid) begin
            angle_buf[ptr] <= ang_in;
        end
        // angle_valid = 0 -> buffer 不變
    end

    // --------------------------------------------------
    // buf_valid：對齊 angle_valid（1-cycle pulse）
    // --------------------------------------------------
    always_ff @(posedge clk or posedge rst) begin
        if (rst)
            buf_valid <= 1'b0;
        else
            buf_valid <= angle_valid;
    end

    assign write_ptr = ptr;

endmodule
