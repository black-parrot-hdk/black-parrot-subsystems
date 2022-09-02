`include "bsg_defines.v"

module mem_1r1w_sync #(
    parameter `BSG_INV_PARAM(width_p)
  , parameter `BSG_INV_PARAM(els_p)
  , localparam addr_width_lp=`BSG_SAFE_CLOG2(els_p)
)
(
    input                                        w_clk_i
  , input                                        w_v_i
  , input [addr_width_lp-1:0]                    w_addr_i
  , input [`BSG_SAFE_MINUS(width_p, 1):0]        w_data_i

  , input                                        r_clk_i
  , input                                        r_v_i
  , input [addr_width_lp-1:0]                    r_addr_i
  , output logic [`BSG_SAFE_MINUS(width_p, 1):0] r_data_o
);

  logic [width_p-1:0] mem [els_p-1:0];
  always @(posedge w_clk_i) begin
    if(w_v_i)
      mem[w_addr_i] <= w_data_i;
  end

  // TODO: should latch the last read
  always @(posedge r_clk_i) begin
    if(r_v_i)
      r_data_o <= mem[r_addr_i];
    else
      r_data_o <= 'X;
  end
endmodule
