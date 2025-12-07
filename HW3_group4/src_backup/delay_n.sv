`timescale 1ns/1ps
`include "../include/data_type.svh"

module delay_n #(
    parameter N = 256
) (
    input           clk,
    input           rst,
    input           in_valid,
    input  r_t      rx_re_in,
    input  r_t      rx_img_in,
    
    output reg      delay_n_valid,
    output r_t      r_real,
    output r_t      r_imag,
    output r_t      r_dN_real,
    output r_t      r_dN_imag
);

    r_t delay_line_real [0:N-1];
    r_t delay_line_imag [0:N-1];

    r_t r_real_buf;
    r_t r_imag_buf;
    r_t r_dN_real_buf;
    r_t r_dN_imag_buf;

    assign r_real    = r_real_buf;
    assign r_imag    = r_imag_buf;
    assign r_dN_real = r_dN_real_buf;
    assign r_dN_imag = r_dN_imag_buf;

    integer i;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            delay_n_valid <= 1'b0;
            r_real_buf    <= '0;
            r_imag_buf    <= '0;
            r_dN_real_buf <= '0;
            r_dN_imag_buf <= '0;
            for (i = 0; i < N; i = i + 1) begin
                delay_line_real[i] <= '0;
                delay_line_imag[i] <= '0;
            end
        end
        else begin
            if (in_valid) begin
                delay_n_valid <= 1'b1;
                r_real_buf    <= rx_re_in;
                r_imag_buf    <= rx_img_in;
                r_dN_real_buf <= delay_line_real[N-1];
                r_dN_imag_buf <= delay_line_imag[N-1];

                for (i = N-1; i > 0; i = i - 1) begin
                    delay_line_real[i] <= delay_line_real[i-1];
                    delay_line_imag[i] <= delay_line_imag[i-1];
                end
                delay_line_real[0] <= rx_re_in;
                delay_line_imag[0] <= rx_img_in;
            end
            else begin
                delay_n_valid <= 1'b0;
            end
        end
    end
endmodule
