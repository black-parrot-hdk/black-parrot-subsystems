/*
Copyright (c) 2015-2016 Alex Forencich
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

module wb_ram #
(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 16,
    parameter SELECT_WIDTH = (DATA_WIDTH/8)
)
(
    input  wire                    clk,
    input  wire                    reset,

    input  wire [ADDR_WIDTH-1:0]   adr_i,
    input  wire [DATA_WIDTH-1:0]   dat_i,
    input  wire                    cyc_i,
    input  wire                    stb_i,
    input  wire [SELECT_WIDTH-1:0] sel_i,
    input  wire                    we_i,
    output wire [DATA_WIDTH-1:0]   dat_o,
    output wire                    ack_o
);

parameter VALID_ADDR_WIDTH = ADDR_WIDTH - $clog2(SELECT_WIDTH);
parameter WORD_WIDTH = SELECT_WIDTH;
parameter WORD_SIZE = DATA_WIDTH/WORD_WIDTH;

reg [DATA_WIDTH-1:0] dat_o_reg = {DATA_WIDTH{1'b0}};
reg ack_o_reg = 1'b0;

reg [DATA_WIDTH-1:0] mem[(2**VALID_ADDR_WIDTH)-1:0];

wire [VALID_ADDR_WIDTH-1:0] adr_i_valid = adr_i >> (ADDR_WIDTH - VALID_ADDR_WIDTH);

assign dat_o = dat_o_reg;
assign ack_o = ack_o_reg;

integer i, j;

initial begin
    // two nested loops for smaller number of iterations per loop
    // workaround for synthesizer complaints about large loop counts
    for (i = 0; i < 2**VALID_ADDR_WIDTH; i = i + 2**(VALID_ADDR_WIDTH/2)) begin
        for (j = i; j < i + 2**(VALID_ADDR_WIDTH/2); j = j + 1) begin
            mem[j] = 0;
        end
    end
end

always @(posedge clk) begin
    ack_o_reg <= 1'b0;
    for (i = 0; i < WORD_WIDTH; i = i + 1) begin
        if (cyc_i & stb_i & ~ack_o & ~reset) begin
            if (we_i & sel_i[i]) begin
                mem[adr_i_valid][WORD_SIZE*i +: WORD_SIZE] <= dat_i[WORD_SIZE*i +: WORD_SIZE];
            end
            dat_o_reg[WORD_SIZE*i +: WORD_SIZE] <= mem[adr_i_valid][WORD_SIZE*i +: WORD_SIZE];
            ack_o_reg <= 1'b1;
        end
    end
end

endmodule
