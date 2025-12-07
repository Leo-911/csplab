`timescale 1ns/1ps

module cordic_vectoring #(
    parameter int WL = 24,    // 輸入位寬 (s7.17)
    parameter int ITER = 20   // 迭代次數
)(
    input  logic clk,
    input  logic rst, // Synchronous Reset
    input  logic en,
    input  logic signed [WL-1:0] x_in, // Real
    input  logic signed [WL-1:0] y_in, // Imag
    
    output logic out_valid,
    output logic signed [WL-1:0] mag_out,
    output logic signed [23:0]   phase_out 
);

    // ★★★ 修正：使用 Function 定義常數表 (可合成) ★★★
    function automatic logic signed [23:0] get_atan(input int idx);
        case(idx)
            0:  return 24'd1647099;
            1:  return 24'd972683;
            2:  return 24'd514059;
            3:  return 24'd260931;
            4:  return 24'd130986;
            5:  return 24'd65597;
            6:  return 24'd32808;
            7:  return 24'd16405;
            8:  return 24'd8203;
            9:  return 24'd4101;
            10: return 24'd2051;
            11: return 24'd1025;
            12: return 24'd513;
            13: return 24'd256;
            14: return 24'd128;
            15: return 24'd64;
            16: return 24'd32;
            17: return 24'd16;
            18: return 24'd8;
            19: return 24'd4;
            default: return 24'd0;
        endcase
    endfunction

    // Pipeline Registers
    logic signed [WL+1:0] x_pipe [0:ITER];
    logic signed [WL+1:0] y_pipe [0:ITER];
    logic signed [23:0]   z_pipe [0:ITER];
    logic                 v_pipe [0:ITER];

    // Pre-rotation Logic
    logic signed [WL+1:0] x_pre, y_pre;
    logic signed [23:0]   z_pre;
    
    localparam signed [23:0] PI_VAL = 24'd6588397;

    always_comb begin
        if (x_in < 0) begin
            x_pre = -x_in;
            y_pre = -y_in;
            if (y_in < 0) z_pre = -PI_VAL;
            else          z_pre = PI_VAL;
        end else begin
            x_pre = x_in;
            y_pre = y_in;
            z_pre = 0;
        end
    end

    // Stage 0 Injection (Sync Reset)
    always_ff @(posedge clk) begin
        if (rst) begin
            x_pipe[0] <= 0; y_pipe[0] <= 0; z_pipe[0] <= 0; v_pipe[0] <= 0;
        end else begin
            x_pipe[0] <= x_pre;
            y_pipe[0] <= y_pre;
            z_pipe[0] <= z_pre;
            v_pipe[0] <= en;
        end
    end

    // Pipeline Stages
    genvar i;
    generate
        for (i = 0; i < ITER; i++) begin : cordic_stage
            
            // 取得當前級數的旋轉角度 (Synthesis Friendly)
            wire signed [23:0] current_atan = get_atan(i);

            always_ff @(posedge clk) begin
                if (rst) begin
                    x_pipe[i+1] <= 0; y_pipe[i+1] <= 0; z_pipe[i+1] <= 0; v_pipe[i+1] <= 0;
                end else begin
                    v_pipe[i+1] <= v_pipe[i];
                    
                    if (y_pipe[i] >= 0) begin 
                        x_pipe[i+1] <= x_pipe[i] + (y_pipe[i] >>> i);
                        y_pipe[i+1] <= y_pipe[i] - (x_pipe[i] >>> i);
                        z_pipe[i+1] <= z_pipe[i] + current_atan; // 使用 wire
                    end else begin 
                        x_pipe[i+1] <= x_pipe[i] - (y_pipe[i] >>> i);
                        y_pipe[i+1] <= y_pipe[i] + (x_pipe[i] >>> i);
                        z_pipe[i+1] <= z_pipe[i] - current_atan; // 使用 wire
                    end
                end
            end
        end
    endgenerate

    assign out_valid = v_pipe[ITER];
    
    always_comb begin
        mag_out = x_pipe[ITER][WL-1:0]; 
        phase_out = z_pipe[ITER];
    end

endmodule