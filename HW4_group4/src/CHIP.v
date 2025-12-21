`include "top.sv"
module CHIP(
    input  clk,
    input  rst,
    input  in_valid,
    input  signed  [15:0] rx_re_in,
    input  signed  [15:0] rx_img_in,
    input  [7:0] rho,
    output [7:0]   theta,
    output [20:0]   epsilon, // Q1.20
    output out_valid
);

//i
wire clk_core, rst_core, in_valid_core;
wire [15:0] rx_re_in_core;
wire [15:0] rx_img_in_core;
wire [7:0] rho_core;

//o
wire [7:0] theta_core;
wire out_valid_core;
wire [20:0] epsilon_core;

//instance
top #(
    .INT_BITS(1),  
    .FRAC_BITS(15),
    .RHO_INT_BITS(1),
    .RHO_FRAC_BITS(7)
) top(
    .clk(clk_core),
    .rst(rst_core),
    .in_valid(in_valid_core),
    .rx_re_in(rx_re_in_core),
    .rx_img_in(rx_img_in_core),
    .rho(rho_core),
    .theta(theta_core),
    .epsilon(epsilon_core),
    .out_valid(out_valid_core)
);

genvar i;
//可以自由決定iopad的擺放位置，需要自己加
//top           // clk, rst, rx_re_in (18pin)
PDCDG_V ipad_clk (.C(clk_core), .I(1'b0), .IE(1'b1), .OEN(1'b1), .PAD(clk));
PDCDG_V ipad_rst (.C(rst_core), .I(1'b0), .IE(1'b1), .OEN(1'b1), .PAD(rst));
generate
    for(i=0; i<16; i=i+1) begin : rx_re
        PDCDG_V ipad_rx_re (.C(rx_re_in_core[i]), .I(1'b0), .IE(1'b1), .OEN(1'b1), .PAD(rx_re_in[i]));
    end
endgenerate

//left          // rx_img_in (16pin)
//PDCDG_H opad_epsilon0 (.C(), .I(epsilon_core[0]), .IE(1'b0), .OEN(1'b0), .PAD(epsilon[0]));
PDCDG_H ipad_in_valid (.C(in_valid_core), .I(1'b0), .IE(1'b1), .OEN(1'b1), .PAD(in_valid));
generate
    for(i=0; i<16; i=i+1) begin : rx_img
        PDCDG_H ipad_rx_img (.C(rx_img_in_core[i]), .I(1'b0), .IE(1'b1), .OEN(1'b1), .PAD(rx_img_in[i]));
    end
endgenerate

//bottom        // rho, theta, out_valid (17pin)
generate
    for(i=0; i<8; i=i+1) begin : rho
        PDCDG_V ipad_rho (.C(rho_core[i]), .I(1'b0), .IE(1'b1), .OEN(1'b1), .PAD(rho[i]));
    end

    for(i=0; i<8; i=i+1) begin : theta
        PDCDG_V opad_theta (.C(), .I(theta_core[i]), .IE(1'b0), .OEN(1'b0), .PAD(theta[i]));
    end
endgenerate
PDCDG_V opad_out_valid (.C(), .I(out_valid_core), .IE(1'b0), .OEN(1'b0), .PAD(out_valid));

//right         // epsilon (20pin)
generate
    for(i=0; i<21; i=i+1) begin : eps
        PDCDG_H opad_eps (.C(), .I(epsilon_core[i]), .IE(1'b0), .OEN(1'b0), .PAD(epsilon[i]));
    end
endgenerate

endmodule