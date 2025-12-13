`timescale 1ns/1ps
`include "../include/data_type.svh"

module angle (
    input           clk,
    input           rst,
    // Control Signals
    input           gamma_sum_valid,  // 來自 gamma_sum
    output reg         angle_valid,      // 輸出給後級（未來接 argmax）
    // Data Signals
    input  gamma_t  gamma_in_real,    // x
    input  gamma_t  gamma_in_imag,    // y
    output ang_t    ang_out       // atan2(y,x) result（Q3.10）
);
    // ------------------------------------------------------------
    // CORDIC Parameters
    // ------------------------------------------------------------
    localparam int ITERS = 8;     // Iterations

    // Constants (Q3.10 based on ang_t logic signed [12:0])
    // PI/2 = 1.5708 * 1024 = 1608
    localparam signed [12:0] HALF_PI     = 13'sd1608;
    localparam signed [12:0] NEG_HALF_PI = -13'sd1608;

    // ATAN Table (Q3.10)
    localparam signed [12:0] ATAN_LUT[0:ITERS-1] = '{
        13'sd804, 13'sd475, 13'sd251, 13'sd127, 
        13'sd64,  13'sd32,  13'sd16,  13'sd8
    };

    // ------------------------------------------------------------
    // Internal Signals
    // ------------------------------------------------------------
    // Combinational CORDIC signals
    reg signed [15:0] x_q, y_q;    // Quadrant corrected
    reg signed [12:0] z_q;

    reg signed [15:0] x_iter [0:ITERS];
    reg signed [15:0] y_iter [0:ITERS];
    reg signed [12:0] z_iter [0:ITERS];

    reg signed [12:0] ang_now;     // combinational angle result

    integer i;

    // ------------------------------------------------------------
    // Combinational Logic: CORDIC Algorithm
    // ------------------------------------------------------------
    always @(*) begin
        // 1. Quadrant Correction
        x_q = gamma_in_real;
        y_q = gamma_in_imag;
        z_q = 13'sd0;

        if (gamma_in_real < 0) begin
            if (gamma_in_imag >= 0) begin
                x_q =  gamma_in_imag;
                y_q = -gamma_in_real;
                z_q =  HALF_PI;
            end else begin
                x_q = -gamma_in_imag;
                y_q =  gamma_in_real;
                z_q =  NEG_HALF_PI;
            end
        end

        // 2. Iterations
        x_iter[0] = x_q;
        y_iter[0] = y_q;
        z_iter[0] = z_q;

        for (i = 0; i < ITERS; i = i + 1) begin
            if (y_iter[i] >= 0) begin
                x_iter[i+1] = x_iter[i] + (y_iter[i] >>> i);
                y_iter[i+1] = y_iter[i] - (x_iter[i] >>> i);
                z_iter[i+1] = z_iter[i] + ATAN_LUT[i];
            end else begin
                x_iter[i+1] = x_iter[i] - (y_iter[i] >>> i);
                y_iter[i+1] = y_iter[i] + (x_iter[i] >>> i);
                z_iter[i+1] = z_iter[i] - ATAN_LUT[i];
            end
        end

        // Final result (combinational)
        ang_now = z_iter[ITERS];
    end

    // ------------------------------------------------------------
    // Sequential Logic: 1-cycle output register
    // ------------------------------------------------------------
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            ang_out     <= '0;
            angle_valid <= 1'b0;
        end else begin
            // gamma_sum_valid 為 1 的那一拍，下一拍輸出 ang_out
            ang_out     <= ang_now;
            angle_valid <= gamma_sum_valid;
        end
    end

endmodule

