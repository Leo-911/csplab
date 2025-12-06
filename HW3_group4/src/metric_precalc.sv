`timescale 1ns/1ps

module metric_precalc #(
    parameter int WL_IN    = 16, 
    parameter int WL_RHO   = 8,  
    parameter int WL_OUT   = 20, 
    parameter int FFT_SIZE = 256 
)(
    input  logic clk,
    input  logic rst,
    input  logic in_valid,
    input  logic signed [WL_IN-1:0] r_real_in,
    input  logic signed [WL_IN-1:0] r_imag_in,
    input  logic signed [WL_RHO-1:0] rho_in,
    
    output logic out_valid,
    output logic signed [WL_OUT-1:0] corr_real_out,
    output logic signed [WL_OUT-1:0] corr_imag_out,
    output logic signed [WL_OUT-1:0] energy_out
);

    // ==========================================
    // Stage 1: Input & Memory Access
    // ==========================================
    logic signed [WL_IN-1:0] mem_real [0:FFT_SIZE-1];
    logic signed [WL_IN-1:0] mem_imag [0:FFT_SIZE-1];
    logic [7:0] ptr;
    logic filled;
    
    logic signed [WL_IN-1:0] r_real_d1, r_imag_d1;
    logic signed [WL_IN-1:0] r_real_del_d1, r_imag_del_d1;
    logic signed [WL_RHO-1:0] rho_d1;
    logic in_valid_d1;

    logic signed [WL_IN-1:0] r_real_del_comb, r_imag_del_comb;
    assign r_real_del_comb = filled ? mem_real[ptr] : '0;
    assign r_imag_del_comb = filled ? mem_imag[ptr] : '0;

    always_ff @(posedge clk) begin
        if (rst) begin
            ptr <= '0; filled <= 1'b0;
            r_real_d1 <= '0; r_imag_d1 <= '0;
            r_real_del_d1 <= '0; r_imag_del_d1 <= '0;
            rho_d1 <= '0; in_valid_d1 <= 0;
        end else begin
            if (in_valid) begin
                mem_real[ptr] <= r_real_in;
                mem_imag[ptr] <= r_imag_in;
                if (ptr == FFT_SIZE - 1) begin
                    ptr <= '0; filled <= 1'b1;
                end else begin
                    ptr <= ptr + 1;
                end
            end
            
            // Pipeline Stage 1 Register
            if (in_valid) begin
                r_real_d1 <= r_real_in;
                r_imag_d1 <= r_imag_in;
                r_real_del_d1 <= r_real_del_comb;
                r_imag_del_d1 <= r_imag_del_comb;
                rho_d1    <= rho_in;
            end
            in_valid_d1 <= in_valid;
        end
    end

    // ==========================================
    // Stage 2: Multiplications (Squares)
    // ==========================================
    logic signed [2*WL_IN-1:0] mult_ac_reg, mult_bd_reg, mult_bc_reg, mult_ad_reg;
    logic signed [2*WL_IN-1:0] sq_curr_r_reg, sq_curr_i_reg, sq_del_r_reg, sq_del_i_reg;
    logic signed [WL_RHO-1:0] rho_d2;
    logic in_valid_d2;

    always_ff @(posedge clk) begin
        if (rst) begin
            mult_ac_reg <= '0; mult_bd_reg <= '0; mult_bc_reg <= '0; mult_ad_reg <= '0;
            sq_curr_r_reg <= '0; sq_curr_i_reg <= '0; sq_del_r_reg <= '0; sq_del_i_reg <= '0;
            rho_d2 <= '0; in_valid_d2 <= 0;
        end else begin
            // Multiplies
            mult_ac_reg <= r_real_d1 * r_real_del_d1;
            mult_bd_reg <= r_imag_d1 * r_imag_del_d1;
            mult_bc_reg <= r_imag_d1 * r_real_del_d1;
            mult_ad_reg <= r_real_d1 * r_imag_del_d1;
            
            sq_curr_r_reg <= r_real_d1 * r_real_d1;
            sq_curr_i_reg <= r_imag_d1 * r_imag_d1;
            sq_del_r_reg  <= r_real_del_d1 * r_real_del_d1;
            sq_del_i_reg  <= r_imag_del_d1 * r_imag_del_d1;
            
            rho_d2 <= rho_d1;
            in_valid_d2 <= in_valid_d1;
        end
    end

    // ==========================================
    // Stage 3: Additions Only (Split from Scaling)
    // ==========================================
    // ★★★ 關鍵優化：在這裡插入 Pipeline Register ★★★
    // 讓加法做完就存起來，不要跟後面的乘法擠在同一個 Cycle
    
    logic signed [2*WL_IN:0] corr_real_sum_reg, corr_imag_sum_reg;
    logic signed [2*WL_IN+1:0] sum_mag_reg; // 這裡存 Energy Sum
    logic signed [WL_RHO-1:0] rho_d3;
    logic in_valid_d3;
    
    always_ff @(posedge clk) begin
        if (rst) begin
            corr_real_sum_reg <= '0; corr_imag_sum_reg <= '0;
            sum_mag_reg <= '0;
            rho_d3 <= '0; in_valid_d3 <= 0;
        end else begin
            // Correlation Additions
            corr_real_sum_reg <= mult_ac_reg + mult_bd_reg;
            corr_imag_sum_reg <= mult_bc_reg - mult_ad_reg;
            
            // Energy Additions (Two steps in one cycle is fine for adders)
            // sq + sq + sq + sq -> sum_mag
            // 20-bit adder delay is small (~0.1ns)
            sum_mag_reg <= (sq_curr_r_reg + sq_curr_i_reg) + (sq_del_r_reg + sq_del_i_reg);
            
            rho_d3 <= rho_d2;
            in_valid_d3 <= in_valid_d2;
        end
    end

    // ==========================================
    // Stage 4: Scaling (Multiply by Rho)
    // ==========================================
    // 現在這裡只剩下一個乘法器，時間非常充裕
    
    logic signed [2*WL_IN+1+WL_RHO:0] energy_mult_rho;
    logic signed [2*WL_IN+1+WL_RHO:0] energy_div2;
    
    always_comb begin
        energy_mult_rho = sum_mag_reg * rho_d3;
        energy_div2     = energy_mult_rho >>> 1;
    end

    // ==========================================
    // Output Stage
    // ==========================================
    localparam int SHIFT_CORR = (2*15) - (WL_OUT-3); 
    localparam int SHIFT_ENERGY = (2*15 + 7) - (WL_OUT-3);

    always_ff @(posedge clk) begin
        if (rst) begin
            corr_real_out <= '0; corr_imag_out <= '0; energy_out <= '0; out_valid <= 0;
        end else begin
            if (in_valid_d3) begin
                corr_real_out <= corr_real_sum_reg >>> SHIFT_CORR;
                corr_imag_out <= corr_imag_sum_reg >>> SHIFT_CORR;
                energy_out    <= energy_div2       >>> SHIFT_ENERGY;
                out_valid     <= 1'b1;
            end else begin
                out_valid     <= 1'b0;
                corr_real_out <= '0; corr_imag_out <= '0; energy_out <= '0;
            end
        end
    end

endmodule