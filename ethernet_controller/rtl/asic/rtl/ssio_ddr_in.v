/*

Copyright (c) 2016-2018 Alex Forencich

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.

*/

// Language: Verilog 2001

`timescale 1ns / 1ps

/*
 * Generic source synchronous DDR input
 */
module ssio_ddr_in #
(
    // Width of register in bits
    parameter WIDTH = 1
)
(
    input  wire             input_clk,

    input  wire [WIDTH-1:0] input_d,

    output wire             output_clk,

    output wire [WIDTH-1:0] output_q1,
    output wire [WIDTH-1:0] output_q2
);

wire clk_int;
reg [WIDTH-1:0] delayed_d;
genvar n;
generate
for (n = 0; n < WIDTH; n = n + 1) begin : iddr
    bsg_link_iddr_phy #(.width_p(1))
      iddr_inst (
        .clk_i(input_clk)
       ,.data_i(input_d[n])
       ,.data_r_o({output_q2[n], output_q1[n]})
      );
end
endgenerate

assign output_clk = input_clk;

endmodule
