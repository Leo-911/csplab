`timescale 1ns/1ps
`include "../include/data_type.svh"

module argmax (
    input           clk,
    input           rst,
    // Control Signals
    input           minus_valid,  // 來自 minus
    output reg      argmax_valid, // 輸出給 select_eps

    // Data Signals
    input  lambda_t lambda,       // Metric value
    output theta_t  theta_out     // Index of max value
);

    // ------------------------------------------------------------
    // Parameters
    // ------------------------------------------------------------
    localparam int N            = 256;
    localparam int PIPE_LATENCY = 9; // 1 (Buffer) + 8 (Tree Levels)
    
    // Min value for 16-bit signed integer (0x8000)
    localparam signed [15:0] MIN_VAL = -16'sd32768; 

    // ------------------------------------------------------------
    // Internal Data Structures
    // ------------------------------------------------------------
    // Internal struct for the tree node
    typedef struct packed {
        lambda_t val;
        theta_t  idx;
    } pair_t;

    // Shift Register Buffer (Window)
    lambda_t data_buffer [0:N-1];

    // Comparator Tree Stages
    // Stage 0 is combinational (wiring), 1-8 are registers
    pair_t stages [0:8][0:N-1];

    // Valid Pipeline to track latency
    reg [PIPE_LATENCY-1:0] valid_pipe;

    integer i;

    // ------------------------------------------------------------
    // 1. Data Buffer (Input Window)
    // ------------------------------------------------------------
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            for (i = 0; i < N; i = i + 1) begin
                data_buffer[i] <= MIN_VAL; 
            end
        end 
        else begin
            if (minus_valid) begin
                // Shift Right: Newest at [0], Oldest at [N-1]
                for (i = N-1; i > 0; i = i - 1) begin
                    data_buffer[i] <= data_buffer[i-1];
                end
                data_buffer[0] <= lambda;
            end
            // Else: Hold data
        end
    end

    // ------------------------------------------------------------
    // 2. Stage 0: Initialization (Combinational)
    // ------------------------------------------------------------
    // Map buffer to tree leaves and assign indices
    always @(*) begin
        for (i = 0; i < N; i = i + 1) begin
            stages[0][i].val = data_buffer[i];
            // idx logic: data_buffer[0] (newest) -> 255
            //            data_buffer[255] (oldest) -> 0
            // 根據您的需求保留此映射
            stages[0][i].idx = 8'(255 - i); 
        end
    end

    // ------------------------------------------------------------
    // 3. Stage 1~8: Pipelined Comparator Tree
    // ------------------------------------------------------------
    genvar level, k;
    generate
        for (level = 0; level < 8; level++) begin : pipe_stage
            // Number of pairs at this level: N / 2^(level+1)
            // L0->L1: 128 pairs, L1->L2: 64 pairs...
            localparam int num_nodes = N >> (level + 1); 
            
            for (k = 0; k < num_nodes; k++) begin : comp_unit
                always @(posedge clk or posedge rst) begin
                    if (rst) begin
                        stages[level+1][k].val <= MIN_VAL;
                        stages[level+1][k].idx <= 8'd0;
                    end 
                    else begin
                        if (minus_valid) begin
                            // Compare adjacent nodes from previous level
                            // If Left >= Right, keep Left
                            if (stages[level][2*k].val >= stages[level][2*k+1].val) begin
                                stages[level+1][k] <= stages[level][2*k];
                            end else begin
                                stages[level+1][k] <= stages[level][2*k+1];
                            end
                        end
                        // Else: Hold state (Pipeline Stall)
                    end
                end
            end
        end
    endgenerate

    // ------------------------------------------------------------
    // 4. Valid Signal Pipeline & Output
    // ------------------------------------------------------------
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            valid_pipe   <= '0;
            argmax_valid <= 1'b0;
        end 
        else begin
            if (minus_valid) begin
                // Shift in '1' to indicate valid data entered the pipe
                valid_pipe <= {valid_pipe[PIPE_LATENCY-2:0], 1'b1};
                
                // Output valid only if the pipe is full (latency matched)
                argmax_valid <= valid_pipe[PIPE_LATENCY-1];
            end 
            else begin
                // Stall mode: Force output valid low
                argmax_valid <= 1'b0;
                // valid_pipe holds its state (waiting for resume)
            end
        end
    end

    // Final Output (Root of the tree)
    assign theta_out = stages[8][0].idx;

endmodule
