
`timescale 1ns / 1ps

module lfsr_gen();

    parameter LFSR_WIDTH = 32;
    parameter LFSR_POLY = 32'h4c11db7;
    parameter LFSR_CONFIG = "GALOIS";
    parameter LFSR_FEED_FORWARD = 0;
    parameter REVERSE = 1;
    parameter DATA_WIDTH = 8;
    parameter STYLE = "AUTO";


    lfsr #(
        .LFSR_WIDTH(LFSR_WIDTH)
       ,.LFSR_POLY(LFSR_POLY)
       ,.LFSR_CONFIG(LFSR_CONFIG)
       ,.LFSR_FEED_FORWARD(LFSR_FEED_FORWARD)
       ,.REVERSE(REVERSE)
       ,.DATA_WIDTH(DATA_WIDTH)
       ,.STYLE(STYLE)
    ) dut (
        .data_in()   // UNUSED
       ,.state_in()  // UNUSED
       ,.data_out()  // UNUSED
       ,.state_out() // UNUSED
    );

    initial begin
        #1;
        $write("/* === Settings ===\n");
        $write(" * LFSR_WIDTH: %0d\n", LFSR_WIDTH);
        $write(" * LFSR_POLY: 0x%x\n", LFSR_POLY);
        $write(" * LFSR_CONFIG: \"%s\"\n", LFSR_CONFIG);
        $write(" * LFSR_FEED_FORWARD: %0d\n", LFSR_FEED_FORWARD);
        $write(" * REVERSE: %0d\n", REVERSE);
        $write(" * DATA_WIDTH: %0d\n", DATA_WIDTH);
        $write(" */\n");
        $write("initial begin\n");
        $write("    if(LFSR_WIDTH != %0d ||\n", LFSR_WIDTH);
        $write("        LFSR_POLY != %0d'h%x ||\n", LFSR_WIDTH, LFSR_POLY);
        $write("        LFSR_CONFIG != \"%s\" ||\n", LFSR_CONFIG);
        $write("        LFSR_FEED_FORWARD != %0d ||\n", LFSR_FEED_FORWARD);
        $write("        REVERSE != %0d ||\n", REVERSE);
        $write("        DATA_WIDTH != %0d) begin\n", DATA_WIDTH);
        $write("        $error(\"Error: unsupported lfsr settings\");\n");
        $write("        $finish;\n");
        $write("    end\n");
        $write("end\n");

        $write("wire [%0d:0][%0d:0] lfsr_mask_state = {\n", LFSR_WIDTH - 1, LFSR_WIDTH - 1);
        for (int i = 0; i < LFSR_WIDTH; i = i + 1) begin
            $write("%0d'b%b", LFSR_WIDTH, dut.lfsr_mask_state[LFSR_WIDTH - 1 - i]);
            if(i != LFSR_WIDTH - 1)
                $write(",");
            $write("\n");
        end
        $write("};\n\n");
        $write("wire [%0d:0][%0d:0] lfsr_mask_data = {\n", LFSR_WIDTH - 1, DATA_WIDTH - 1);
        for (int i = 0; i < LFSR_WIDTH; i = i + 1) begin
            $write("%0d'b%b", DATA_WIDTH, dut.lfsr_mask_data[LFSR_WIDTH - 1 - i]);
            if(i != LFSR_WIDTH - 1)
                $write(",");
            $write("\n");
        end
        $write("};\n\n");
        $write("wire [%0d:0][%0d:0] output_mask_state = {\n", DATA_WIDTH - 1, LFSR_WIDTH - 1);
        for (int i = 0; i < DATA_WIDTH; i = i + 1) begin
            $write("%0d'b%b", LFSR_WIDTH, dut.output_mask_state[DATA_WIDTH - 1 - i]);
            if(i != DATA_WIDTH - 1)
                $write(",");
            $write("\n");
        end
        $write("};\n\n");
        $write("wire [%0d:0][%0d:0] output_mask_data = {\n", DATA_WIDTH - 1, DATA_WIDTH - 1);
        for (int i = 0; i < DATA_WIDTH; i = i + 1) begin
            $write("%0d'b%b", DATA_WIDTH, dut.output_mask_data[DATA_WIDTH - 1 - i]);
            if(i != DATA_WIDTH - 1)
                $write(",");
            $write("\n");
        end
        $write("};\n\n");
        $write("integer i, j, k;\n");
    end

endmodule
