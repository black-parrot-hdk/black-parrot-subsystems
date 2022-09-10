`include "bsg_defines.v"

module bsg_async_store_and_forward #(
    parameter `BSG_INV_PARAM(width_p)
  , parameter upstream_async_fifo_p = 0
)
(
    input                      aclk_i
  , input                      areset_i

  , input                      bclk_i
  , input                      breset_i

  , input [width_p-1:0]        adata_i
  , input                      av_i
  , input                      alast_i
  , input                      aerror_i
  , output logic               aready_and_o

  , output logic [width_p-1:0] bdata_o
  , output logic               bv_o
  , output logic               blast_o
  , input                      bready_and_i
);

if (upstream_async_fifo_p != 0) begin

  bsg_async_fifo #(
    .width_p(width_p)
    ,.lg_size_p(3)
  ) upstream_cdc (
    .w_clk_i(aclk_i)
    ,.w_reset_i(areset_i)
    ,.w_enq_i()
    ,.w_data_i()
    ,.w_full_o(w_full_lo)

    ,.r_clk_i()
    ,.r_reset_i()
    ,.r_deq_i()
    ,.r_data_o()
    ,.r_valid_o()
  );
end

  bsg_store_and_forward #(
    .width_p(width_p)
  ) saf (

  );

if (upstream_async_fifo_p == 0) begin

  bsg_async_fifo #(
    .width_p(width_p)
    ,.lg_size_p(3)
  ) downstream_cdc (
    
  );

end

endmodule

