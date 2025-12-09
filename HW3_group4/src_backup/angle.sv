`timescale 1ns/1ps
`include "../include/data_type.svh"

module angle (
    input           clk,
    input           rst,
    // Control Signals
    input           gamma_sum_valid,  // 來自 gamma_sum
    output reg      angle_valid,      // 輸出給 buf

    // Data Signals
    input  gamma_t  gamma_in_real,    // x
    input  gamma_t  gamma_in_imag,    // y
    output ang_t    ang_out           // atan2(y,x) result
);

    // ------------------------------------------------------------
    // CORDIC Parameters
    // ------------------------------------------------------------
    localparam int ITERS = 8;     // Iterations
    localparam int DLY   = 8;     // Delay Line Length

    // Constants (Q3.10 based on ang_t logic signed [12:0])
    // PI/2 = 1.5708 * 1024 = 1608
    localparam signed [12:0] HALF_PI     = 13'sd1608;
    localparam signed [12:0] NEG_HALF_PI = -13'sd1608;

    // ATAN Table (Q3.10)
    // 必須宣告為 signed 以支援正確的加減運算
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
    
    reg signed [12:0] ang_now;     // Current calculated angle

    // Sequential signals (Delay Line)
    reg signed [12:0] dly_reg [0:DLY-1];
    reg [DLY-1:0]     valid_pipe;  // 用來追蹤管線是否填滿 valid 數據

    // Loop variable
    integer i;

    // ------------------------------------------------------------
    // Combinational Logic: CORDIC Algorithm
    // ------------------------------------------------------------
    always @(*) begin
        // 1. Quadrant Correction
        // Initialize
        x_q = gamma_in_real;
        y_q = gamma_in_imag;
        z_q = 0;

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
            // Arithmetic Shift
            // Temp variables for shifting to ensure correct signed behavior
            // x_iter is 16-bit
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

        // Final result of this stage
        ang_now = z_iter[ITERS];
    end

    // ------------------------------------------------------------
    // Sequential Logic: Delay Line & Valid Control
    // ------------------------------------------------------------
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            angle_valid <= 1'b0;
            valid_pipe  <= '0;
            ang_out     <= '0;
            for (i = 0; i < DLY; i = i + 1) begin
                dly_reg[i] <= '0;
            end
        end else begin
        // ❶ data pipeline：每拍都 shift
            for (i = DLY-1; i > 0; i = i - 1) begin
                dly_reg[i] <= dly_reg[i-1];
            end
            dly_reg[0] <= ang_now;

        // ❷ valid pipeline：每拍都 shift，灌入 gamma_sum_valid
            valid_pipe <= {valid_pipe[DLY-2:0], gamma_sum_valid};

        // ❸ output：尾端資料 + 對齊過的 valid
            ang_out     <= dly_reg[DLY-1];
            angle_valid <= valid_pipe[DLY-1];
        end
end


endmodule
