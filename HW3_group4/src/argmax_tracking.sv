`timescale 1ns/1ps
`include "cordic_vectoring.sv"

module argmax_tracking #(
    parameter int WL_IN  = 24, 
    parameter int WL_OUT_THETA = 8,
    parameter int WL_OUT_EPS = 21
)(
    input  logic clk,
    input  logic rst,
    input  logic in_valid,
    input  logic signed [WL_IN-1:0] sum_r_in,
    input  logic signed [WL_IN-1:0] sum_i_in,
    input  logic signed [WL_IN-1:0] sum_e_in,
    
    input  logic start_search, 
    
    output logic search_done, 
    output logic signed [WL_OUT_THETA-1:0] theta_est,
    output logic signed [WL_OUT_EPS-1:0]   epsilon_est
);

    // 1. CORDIC Instantiation
    logic cordic_val;
    logic signed [WL_IN-1:0] mag_raw;
    logic signed [23:0]      phase_raw;
    
    cordic_vectoring #(.WL(WL_IN), .ITER(20)) u_cordic (
        .clk(clk), .rst(rst), .en(in_valid),
        .x_in(sum_r_in), .y_in(sum_i_in),
        .out_valid(cordic_val),
        .mag_out(mag_raw),
        .phase_out(phase_raw)
    );

    // 2. Metric Calculation
    localparam int LATENCY = 21;
    logic signed [WL_IN-1:0] e_pipe [0:LATENCY-1];
    
    always_ff @(posedge clk) begin
        if (rst) begin
            for(int i=0; i<LATENCY; i++) e_pipe[i] <= '0;
        end else begin
            e_pipe[0] <= sum_e_in;
            for(int i=0; i<LATENCY-1; i++) e_pipe[i+1] <= e_pipe[i];
        end
    end
    
    logic signed [WL_IN-1:0] e_aligned;
    assign e_aligned = e_pipe[LATENCY-1];
    
    logic signed [WL_IN+2:0] e_scaled;
    always_comb begin
        e_scaled = e_aligned + (e_aligned >>> 1) + (e_aligned >>> 3) + (e_aligned >>> 6) + (e_aligned >>> 9);
    end

    logic signed [WL_IN+2:0] metric_comb;
    assign metric_comb = mag_raw - e_scaled;

    // ==========================================
    // ★★★ Pipeline Stage 1: Latch Data ★★★
    // ==========================================
    logic signed [WL_IN+2:0] metric_reg;
    logic signed [23:0] phase_reg;
    logic cordic_val_d; 
    
    logic [7:0] counter_reg;      // 給 Stage 2 用的計數器
    logic [7:0] internal_counter; // 內部自增計數器

    always_ff @(posedge clk) begin
        if (rst) begin
            metric_reg <= '0;
            phase_reg <= '0;
            cordic_val_d <= 1'b0;
            internal_counter <= 8'd241; // Preset -15
            counter_reg <= 8'd241;
        end else begin
            // 只有當 Valid 時才動作
            if (cordic_val) begin
                metric_reg <= metric_comb;
                phase_reg  <= phase_raw;
                
                // ★★★ 修正點：傳遞當前 Counter 值，確保與 Metric 對齊 ★★★
                counter_reg <= internal_counter; 
                
                // 準備下一個 Cycle 的計數
                internal_counter <= internal_counter + 1;
            end
            
            cordic_val_d <= cordic_val;
        end
    end

    // ==========================================
    // 3. Peak Search Logic (Stage 2)
    // ==========================================
    logic signed [WL_IN+2:0] max_metric;
    
    logic [7:0] best_theta_curr;
    logic signed [23:0] best_phase_curr;
    
    logic [7:0] theta_out;
    logic signed [23:0] phase_out;
    
    logic [1:0] window_state; 
    logic search_done_reg;

    always_ff @(posedge clk) begin
        if (rst) begin
            max_metric <= {1'b1, {(WL_IN+2){1'b0}}}; 
            
            best_theta_curr <= 0;
            best_phase_curr <= 0;
            theta_out <= 0;
            phase_out <= 0;
            
            search_done_reg <= 0;
            window_state <= 0; 
            
        end else if (cordic_val_d) begin // Stage 2 Enable
            
            // Compare (使用對齊後的 metric_reg 和 counter_reg)
            if (metric_reg > max_metric) begin
                max_metric <= metric_reg;
                best_theta_curr <= counter_reg;
                best_phase_curr <= phase_reg;
            end
            
            // Window End Check
            if (counter_reg == 8'd255) begin
                
                max_metric <= {1'b1, {(WL_IN+2){1'b0}}}; 
                
                case (window_state)
                    0: begin 
                        search_done_reg <= 1'b0;
                        window_state <= 1;
                    end
                    1: begin 
                        search_done_reg <= 1'b0; 
                        window_state <= 2;       
                    end
                    2: begin 
                        search_done_reg <= 1'b1; 
                        
                        // 邊界檢查 (如果 255 是 Peak)
                        if (metric_reg > max_metric) begin
                            theta_out <= counter_reg;
                            phase_out <= phase_reg;
                        end else begin
                            theta_out <= best_theta_curr;
                            phase_out <= best_phase_curr;
                        end
                    end
                endcase
                
            end else begin
                search_done_reg <= 1'b0;
            end
            
        end else begin
            search_done_reg <= 1'b0;
        end
    end

    // ==========================================
    // 4. Epsilon Calculation
    // ==========================================
    localparam signed [32:0] INV_2PI = 33'd683565276; 
    logic signed [56:0] eps_mult;
    assign eps_mult = phase_out * INV_2PI;
    logic signed [56:0] eps_rounded;
    assign eps_rounded = eps_mult + (57'd1 <<< 32); 
    
    assign epsilon_est = eps_rounded >>> 33;
    assign theta_est = theta_out;
    assign search_done = search_done_reg;

endmodule