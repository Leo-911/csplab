`timescale 1ns/1ps

// 子模組：單通道移動加總 (Circular Buffer 版)
module moving_sum_core #(
    parameter int WL_IN  = 20,
    parameter int WL_OUT = 24,
    parameter int L      = 16 
)(
    input  logic clk,
    input  logic rst,
    input  logic en,
    input  logic signed [WL_IN-1:0] data_in,
    output logic signed [WL_OUT-1:0] data_out
);

    // RAM + Pointer 取代 Shift Register
    logic signed [WL_IN-1:0] ram [0:L-1];
    logic [3:0] ptr; // L=16, 4 bits is enough
    logic filled;
    
    logic signed [WL_IN-1:0] delayed_data;
    logic signed [WL_OUT-1:0] acc;

    // 讀出舊值 (如果未滿則為0)
    assign delayed_data = filled ? ram[ptr] : '0;

    always_ff @(posedge clk) begin
        if (rst) begin
            ptr <= '0;
            filled <= 1'b0;
            acc <= '0;
            // No reset for ram needed
        end else if (en) begin
            // 1. Write RAM
            ram[ptr] <= data_in;
            
            // 2. Update Pointer
            if (ptr == L-1) begin
                ptr <= '0;
                filled <= 1'b1;
            end else begin
                ptr <= ptr + 1;
            end
            
            // 3. Accumulate
            acc <= acc + signed'(data_in) - signed'(delayed_data);
        end
    end

    assign data_out = acc;

endmodule

// 主模組 (Wrapper) 保持不變，只需呼叫上面的子模組
module metric_summation #(
    parameter int WL_IN  = 20,
    parameter int WL_OUT = 24,
    parameter int L      = 16
)(
    input  logic clk,
    input  logic rst,
    input  logic in_valid,
    input  logic signed [WL_IN-1:0] corr_real_in,
    input  logic signed [WL_IN-1:0] corr_imag_in,
    input  logic signed [WL_IN-1:0] energy_in,
    
    output logic out_valid,
    output logic signed [WL_OUT-1:0] sum_corr_real,
    output logic signed [WL_OUT-1:0] sum_corr_imag,
    output logic signed [WL_OUT-1:0] sum_energy
);

    always_ff @(posedge clk) begin
        if (rst) out_valid <= 1'b0;
        else     out_valid <= in_valid;
    end

    moving_sum_core #(.WL_IN(WL_IN), .WL_OUT(WL_OUT), .L(L)) u_sum_real (
        .clk(clk), .rst(rst), .en(in_valid), .data_in(corr_real_in), .data_out(sum_corr_real));

    moving_sum_core #(.WL_IN(WL_IN), .WL_OUT(WL_OUT), .L(L)) u_sum_imag (
        .clk(clk), .rst(rst), .en(in_valid), .data_in(corr_imag_in), .data_out(sum_corr_imag));

    moving_sum_core #(.WL_IN(WL_IN), .WL_OUT(WL_OUT), .L(L)) u_sum_energy (
        .clk(clk), .rst(rst), .en(in_valid), .data_in(energy_in), .data_out(sum_energy));

endmodule