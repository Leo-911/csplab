`timescale 1ns/1ps
`include "../include/data_type.svh"

module mag (
    input           clk,
    input           rst,
    // Control Signals
    input           gamma_sum_valid, // 來自 gamma_sum
    output reg      mag_valid,       // 輸出給 minus

    // Data Signals
    input  gamma_t  gamma_in_real,
    input  gamma_t  gamma_in_imag,
    output mag_t    mag_out
);

    // ------------------------------------------------------------
    // Parameter Definitions
    // ------------------------------------------------------------
    localparam int F_GAM   = 10;  // gamma, mag 小數位
    localparam int F_COEF  = 10;  // alpha, beta 小數位
    localparam int F_RATIO = 10;  // ratio 小數位

    // Segment Thresholds (Q0.10)
    localparam signed [15:0] SEG0 = 16'd100; 
    localparam signed [15:0] SEG1 = 16'd204; 
    localparam signed [15:0] SEG2 = 16'd312; 
    localparam signed [15:0] SEG3 = 16'd424; 
    localparam signed [15:0] SEG4 = 16'd548; 
    localparam signed [15:0] SEG5 = 16'd720; 
    localparam signed [15:0] SEG6 = 16'd800; 
    localparam signed [15:0] SEG7 = 16'd840; 

    // Alpha LUT (Q6.10)
    localparam signed [15:0] A0 = 16'sd1230;
    localparam signed [15:0] A1 = 16'sd1018;
    localparam signed [15:0] A2 = 16'sd1001;
    localparam signed [15:0] A3 = 16'sd974; 
    localparam signed [15:0] A4 = 16'sd938; 
    localparam signed [15:0] A5 = 16'sd895; 
    localparam signed [15:0] A6 = 16'sd837; 
    localparam signed [15:0] A7 = 16'sd838; 
    localparam signed [15:0] A8 = 16'sd725; 

    // Beta LUT (Q6.10)
    localparam signed [15:0] B0 = 16'sd25;  
    localparam signed [15:0] B1 = 16'sd126; 
    localparam signed [15:0] B2 = 16'sd225; 
    localparam signed [15:0] B3 = 16'sd322; 
    localparam signed [15:0] B4 = 16'sd416; 
    localparam signed [15:0] B5 = 16'sd505; 
    localparam signed [15:0] B6 = 16'sd591; 
    localparam signed [15:0] B7 = 16'sd591; 
    localparam signed [15:0] B8 = 16'sd721; 

    // ------------------------------------------------------------
    // Internal Signals
    // ------------------------------------------------------------
    reg signed [15:0] ax, ay;         // |x|, |y|
    reg signed [15:0] max_val, min_val;
    reg        [15:0] r;              // ratio = (min/max) in Q0.10
    
    reg signed [15:0] alpha, beta;    // current coefficients
    
    reg signed [31:0] prod_ax;        // alpha * max
    reg signed [31:0] prod_ay;        // beta * min
    reg signed [31:0] sum_prod;       // sum
    
    mag_t             mag_next;       // combinational result

    // ------------------------------------------------------------
    // Combinational Logic: Compute Magnitude
    // ------------------------------------------------------------
    always @(*) begin
        // 1. Absolute Value
        ax = gamma_in_real[15] ? -gamma_in_real : gamma_in_real;
        ay = gamma_in_imag[15] ? -gamma_in_imag : gamma_in_imag;

        // 2. Sort (Max/Min)
        if (ax >= ay) begin
            max_val = ax;
            min_val = ay;
        end else begin
            max_val = ay;
            min_val = ax;
        end

        // Defaults
        alpha    = 0;
        beta     = 0;
        prod_ax  = 0;
        prod_ay  = 0;
        sum_prod = 0;
        mag_next = 0;
        r        = 0;

        if (max_val == 0) begin
            mag_next = 0;
        end else begin
            // 3. Calculate Ratio r = (min / max) * 1024
            // 警告：這是一個組合邏輯除法器，合成面積大且慢。
            // r = (min_val << 10) / max_val
            r = {min_val[15:0], 10'b0} / max_val; // 使用位接合代替 cast，更通用

            // 4. LUT Selection (Comparator Mux)
            if      (r < SEG0) begin alpha = A0; beta = B0; end
            else if (r < SEG1) begin alpha = A1; beta = B1; end
            else if (r < SEG2) begin alpha = A2; beta = B2; end
            else if (r < SEG3) begin alpha = A3; beta = B3; end
            else if (r < SEG4) begin alpha = A4; beta = B4; end
            else if (r < SEG5) begin alpha = A5; beta = B5; end
            else if (r < SEG6) begin alpha = A6; beta = B6; end
            else if (r < SEG7) begin alpha = A7; beta = B7; end
            else               begin alpha = A8; beta = B8; end

            // 5. Linear Approximation: mag = alpha*max + beta*min
            prod_ax  = alpha * max_val;   // Q6.10 * Q6.10 = Q12.20
            prod_ay  = beta  * min_val;   // Q12.20
            sum_prod = prod_ax + prod_ay; // Q12.20

            // 6. Scale Back to Q6.10
            mag_next = sum_prod >>> F_COEF; // Truncate to 16 bits
        end
    end

    // ------------------------------------------------------------
    // Sequential Logic: Output Register & Valid Control
    // ------------------------------------------------------------
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            mag_out   <= 0;
            mag_valid <= 1'b0;
        end else begin
            if (gamma_sum_valid) begin
                // Update output only when input is valid
                mag_out   <= mag_next;
                mag_valid <= 1'b1;
            end else begin
                // Hold value if invalid
                mag_valid <= 1'b0;
            end
        end
    end

endmodule
