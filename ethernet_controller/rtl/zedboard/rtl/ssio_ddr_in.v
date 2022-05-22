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
 * Source synchronous DDR input for Zedboard
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

`ifdef SIM_MP
assign clk_int = input_clk;
`else
// pass through RX clock to logic
BUFR #(
    .BUFR_DIVIDE("BYPASS")
)
clk_bufr (
    .I(input_clk),
    .O(clk_int),
    .CE(1'b1),
    .CLR(1'b0)
);
`endif
genvar n;
generate
for (n = 0; n < WIDTH; n = n + 1) begin : iddr
`ifdef SIM_MP
    assign delayed_d[n] = input_d[n];
`else
    // We need this to meet the timing
    //   requirement for RX side of the RGMII signals
    IDELAYE2 #(
        .DELAY_SRC("IDATAIN")
       ,.IDELAY_TYPE("FIXED")
       ,.IDELAY_VALUE(0)
       ,.REFCLK_FREQUENCY(200.0)
       ,.SIGNAL_PATTERN("DATA")
    ) idelay2_inst (
        .CNTVALUEOUT() // UNUSED
       ,.DATAOUT(delayed_d[n])
       ,.C(1'b0)
       ,.CE(1'b0)
       ,.CINVCTRL(1'b0)
       ,.CNTVALUEIN('0)
       ,.DATAIN() // UNUSED
       ,.IDATAIN(input_d[n])
       ,.INC(1'b0)
       ,.LD(1'b0)
       ,.LDPIPEEN(1'b0)
       ,.REGRST(1'b0)
    );
`endif
    bsg_link_iddr_phy #(.width_p(1))
      iddr_inst (
        .clk_i(clk_int)
       ,.data_i(delayed_d[n])
       ,.data_r_o({output_q2[n], output_q1[n]})
      );
end
endgenerate

assign output_clk = clk_int;

endmodule
