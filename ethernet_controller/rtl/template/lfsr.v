/*** This file is auto-generated from /mnt/users/ssd3/homes/ymchueh/bsg/bump/zynq-parrot2/cosim/import/black-parrot-subsystems/ethernet_controller/rtl/template/lfsr_gen_dir/lfsr_template.v ***/
`default_nettype none

/*
 * Parametrizable combinatorial parallel LFSR/CRC
 */
module lfsr #
(
    // width of LFSR
    parameter LFSR_WIDTH = 31,
    // LFSR polynomial
    parameter LFSR_POLY = 31'h10000001,
    // LFSR configuration: "GALOIS", "FIBONACCI"
    parameter LFSR_CONFIG = "FIBONACCI",
    // LFSR feed forward enable
    parameter LFSR_FEED_FORWARD = 0,
    // bit-reverse input and output
    parameter REVERSE = 0,
    // width of data input
    parameter DATA_WIDTH = 8,
    // implementation style: "AUTO", "LOOP", "REDUCTION"
    parameter STYLE = "AUTO"
)
(
    input  wire [DATA_WIDTH-1:0] data_in,
    input  wire [LFSR_WIDTH-1:0] state_in,
    output wire [DATA_WIDTH-1:0] data_out,
    output wire [LFSR_WIDTH-1:0] state_out
);
/* === Settings ===
 * LFSR_WIDTH: 32
 * LFSR_POLY: 0x04c11db7
 * LFSR_CONFIG: "GALOIS"
 * LFSR_FEED_FORWARD: 0
 * REVERSE: 1
 * DATA_WIDTH: 8
 */
initial begin
    if(LFSR_WIDTH != 32 ||
        LFSR_POLY != 32'h04c11db7 ||
        LFSR_CONFIG != "GALOIS" ||
        LFSR_FEED_FORWARD != 0 ||
        REVERSE != 1 ||
        DATA_WIDTH != 8) begin
        $error("Error: unsupported lfsr settings");
        $finish;
    end
end
wire [31:0][31:0] lfsr_mask_state = {
32'b00000000000000000000000010000010,
32'b00000000000000000000000011000011,
32'b00000000000000000000000011100011,
32'b00000000000000000000000001110001,
32'b00000000000000000000000010111010,
32'b00000000000000000000000011011111,
32'b00000000000000000000000001101111,
32'b00000000000000000000000010110101,
32'b10000000000000000000000011011000,
32'b01000000000000000000000001101100,
32'b00100000000000000000000010110100,
32'b00010000000000000000000011011000,
32'b00001000000000000000000011101110,
32'b00000100000000000000000001110111,
32'b00000010000000000000000000111011,
32'b00000001000000000000000000011101,
32'b00000000100000000000000010001100,
32'b00000000010000000000000001000110,
32'b00000000001000000000000000100011,
32'b00000000000100000000000000010001,
32'b00000000000010000000000000001000,
32'b00000000000001000000000000000100,
32'b00000000000000100000000010000000,
32'b00000000000000010000000011000010,
32'b00000000000000001000000001100001,
32'b00000000000000000100000000110000,
32'b00000000000000000010000010011010,
32'b00000000000000000001000001001101,
32'b00000000000000000000100000100110,
32'b00000000000000000000010000010011,
32'b00000000000000000000001000001001,
32'b00000000000000000000000100000100
};

wire [31:0][7:0] lfsr_mask_data = {
8'b10000010,
8'b11000011,
8'b11100011,
8'b01110001,
8'b10111010,
8'b11011111,
8'b01101111,
8'b10110101,
8'b11011000,
8'b01101100,
8'b10110100,
8'b11011000,
8'b11101110,
8'b01110111,
8'b00111011,
8'b00011101,
8'b10001100,
8'b01000110,
8'b00100011,
8'b00010001,
8'b00001000,
8'b00000100,
8'b10000000,
8'b11000010,
8'b01100001,
8'b00110000,
8'b10011010,
8'b01001101,
8'b00100110,
8'b00010011,
8'b00001001,
8'b00000100
};

wire [7:0][31:0] output_mask_state = {
32'b00000000000000000000000010000010,
32'b00000000000000000000000001000001,
32'b00000000000000000000000000100000,
32'b00000000000000000000000000010000,
32'b00000000000000000000000000001000,
32'b00000000000000000000000000000100,
32'b00000000000000000000000000000010,
32'b00000000000000000000000000000001
};

wire [7:0][7:0] output_mask_data = {
8'b10000010,
8'b01000001,
8'b00100000,
8'b00010000,
8'b00001000,
8'b00000100,
8'b00000010,
8'b00000001
};

integer i, j, k;
// synthesis translate_off
`define SIMULATION
// synthesis translate_on

`ifdef SIMULATION
// "AUTO" style is "REDUCTION" for faster simulation
parameter STYLE_INT = (STYLE == "AUTO") ? "REDUCTION" : STYLE;
`else
// "AUTO" style is "LOOP" for better synthesis result
parameter STYLE_INT = (STYLE == "AUTO") ? "LOOP" : STYLE;
`endif

genvar n;

generate

if (STYLE_INT == "REDUCTION") begin

    // use Verilog reduction operator
    // fast in iverilog
    // significantly larger than generated code with ISE (inferred wide XORs may be tripping up optimizer)
    // slightly smaller than generated code with Quartus
    // --> better for simulation

    for (n = 0; n < LFSR_WIDTH; n = n + 1) begin : loop1
        assign state_out[n] = ^{(state_in & lfsr_mask_state[n]), (data_in & lfsr_mask_data[n])};
    end
    for (n = 0; n < DATA_WIDTH; n = n + 1) begin : loop2
        assign data_out[n] = ^{(state_in & output_mask_state[n]), (data_in & output_mask_data[n])};
    end

end else if (STYLE_INT == "LOOP") begin

    // use nested loops
    // very slow in iverilog
    // slightly smaller than generated code with ISE
    // same size as generated code with Quartus
    // --> better for synthesis

    reg [LFSR_WIDTH-1:0] state_out_reg;
    reg [DATA_WIDTH-1:0] data_out_reg;

    assign state_out = state_out_reg;
    assign data_out = data_out_reg;

    always @* begin
        for (i = 0; i < LFSR_WIDTH; i = i + 1) begin
            state_out_reg[i] = 0;
            for (j = 0; j < LFSR_WIDTH; j = j + 1) begin
                if (lfsr_mask_state[i][j]) begin
                    state_out_reg[i] = state_out_reg[i] ^ state_in[j];
                end
            end
            for (j = 0; j < DATA_WIDTH; j = j + 1) begin
                if (lfsr_mask_data[i][j]) begin
                    state_out_reg[i] = state_out_reg[i] ^ data_in[j];
                end
            end
        end
        for (i = 0; i < DATA_WIDTH; i = i + 1) begin
            data_out_reg[i] = 0;
            for (j = 0; j < LFSR_WIDTH; j = j + 1) begin
                if (output_mask_state[i][j]) begin
                    data_out_reg[i] = data_out_reg[i] ^ state_in[j];
                end
            end
            for (j = 0; j < DATA_WIDTH; j = j + 1) begin
                if (output_mask_data[i][j]) begin
                    data_out_reg[i] = data_out_reg[i] ^ data_in[j];
                end
            end
        end
    end

end else begin

    initial begin
        $error("Error: unknown style setting!");
        $finish;
    end

end

endgenerate

endmodule
