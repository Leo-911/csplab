`timescale 1ns/1ps
`include "include/data_type.svh"

module phi_rho (
    input           clk,
    input           rst,
    input           phi_sum_valid,
    output reg      phi_rho_valid,

    input  phi_t    phi_in,
    input  rho_t    rho_in,
    
    output phi_t    phi_rho
);

    reg signed [23:0] prod_full;
    logic signed [23:0] prod_shifted;
    logic signed [15:0] rho_phi_q6_10;
    
    // 為了保持 1 latency 的結構，我們在 register 後接組合邏輯
    assign prod_shifted  = prod_full >>> 7;
    assign rho_phi_q6_10 = prod_shifted[15:0];
    assign phi_rho       = rho_phi_q6_10; // phi_t is 16-bit

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            prod_full     <= '0;
            phi_rho_valid <= 1'b0;
        end
        else begin
            if (phi_sum_valid) begin
                phi_rho_valid <= 1'b1;
                prod_full     <= rho_in * phi_in;
            end
            else begin
                phi_rho_valid <= 1'b0;
                // prod_full 保持 (Hold)
            end
        end
    end

endmodule