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


//可以自由決定iopad的擺放位置，需要自己加
//top
PDCDG_V ipad_clk (.C(clk_core), .I(1'b0), .IE(1'b1), .OEN(1'b1), .PAD(clk));

//left
PDCDG_H opad_epsilon0 (.C(), .I(epsilon_core[0]), .IE(1'b0), .OEN(1'b0), .PAD(epsilon[0]));

//bottom

//right

endmodule