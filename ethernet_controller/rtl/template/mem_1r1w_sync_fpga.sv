`include "bsg_defines.v"

module mem_1r1w_sync_fpga #(
    parameter `BSG_INV_PARAM(width_p)
  , parameter `BSG_INV_PARAM(els_p)
  , parameter `BSG_INV_PARAM(pipeline_output_p)
  , localparam addr_width_lp=`BSG_SAFE_CLOG2(els_p)
)
(
    input                                        clk_i
  , input                                        reset_i // UNUSED
  , input                                        w_v_i
  , input [addr_width_lp-1:0]                    w_addr_i
  , input [`BSG_SAFE_MINUS(width_p, 1):0]        w_data_i

  , input                                        r_v_i
  , input [addr_width_lp-1:0]                    r_addr_i
  , output logic [`BSG_SAFE_MINUS(width_p, 1):0] r_data_o

  , input                                        output_ready_i
  , input [pipeline_output_p-1:0]                valid_pipe_reg_i
);

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

endmodule
