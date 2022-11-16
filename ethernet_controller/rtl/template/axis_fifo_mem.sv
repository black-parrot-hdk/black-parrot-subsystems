`include "bsg_defines.v"

module axis_fifo_mem #(
    parameter `BSG_INV_PARAM(width_p)
  , parameter `BSG_INV_PARAM(els_p)
  , parameter `BSG_INV_PARAM(pipeline_output_p)
  , localparam addr_width_lp=`BSG_SAFE_CLOG2(els_p)
)
(
    input                                        clk_i
  , input                                        reset_i
  , input                                        w_v_i
  , input [addr_width_lp-1:0]                    w_addr_i
  , input [`BSG_SAFE_MINUS(width_p, 1):0]        w_data_i

  , input                                        r_v_i
  , input [addr_width_lp-1:0]                    r_addr_i
  , output logic [`BSG_SAFE_MINUS(width_p, 1):0] r_data_o

  , input                                        output_ready_i
  , input [pipeline_output_p-1:0]                valid_pipe_reg_i
);

if (pipeline_output_p > 1) begin
  // This block of code is extracted from Alex's axis_fifo. It can work
  // even if pipeline_output_p == 1, but with that setting we might as
  // well use bsg_mem so that this module will also be suitable for ASIC.
  logic [width_p-1:0] pipe_reg [pipeline_output_p-1:0];

  integer j;
  always @(posedge clk_i) begin
    for (j = pipeline_output_p - 1; j > 0; j = j - 1) begin
      if (output_ready_i || ((~valid_pipe_reg_i) >> j)) begin
        // output ready or bubble in pipeline; transfer down pipeline
        pipe_reg[j] <= pipe_reg[j-1];
      end
    end
  end

  logic [width_p-1:0] mem [els_p-1:0];
  always @(posedge clk_i) begin
    if(w_v_i)
      mem[w_addr_i] <= w_data_i;
  end

  always @(posedge clk_i) begin
    if(r_v_i)
      pipe_reg[0] <= mem[r_addr_i];
  end

  assign r_data_o = pipe_reg[pipeline_output_p-1];

end else begin
  // Equivalent code when pipeline_output_p == 1 but suitable for ASIC
  wire unused = | {output_ready_i, valid_pipe_reg_i};

  logic [`BSG_SAFE_MINUS(width_p, 1):0] r_data_lo;
  // latch last read
  logic read_en_r; 
  bsg_dff #(
    .width_p(1)
  ) read_en_dff (
    .clk_i(clk_i)
    ,.data_i(r_v_i)
    ,.data_o(read_en_r)
  );

  bsg_dff_en_bypass #(
    .width_p(width_p)
  ) dff_bypass (
    .clk_i(clk_i)
    ,.en_i(read_en_r)
    ,.data_i(r_data_lo)
    ,.data_o(r_data_o)
  );

  bsg_mem_1r1w_sync #(
     .width_p(width_p)
    ,.els_p(els_p)
  ) mem (
     .clk_i(clk_i)
    ,.reset_i(reset_i)
    ,.w_v_i(w_v_i)
    ,.w_addr_i(w_addr_i)
    ,.w_data_i(w_data_i)

    ,.r_v_i(r_v_i)
    ,.r_addr_i(r_addr_i)
    ,.r_data_o(r_data_lo)
  );
end

endmodule
