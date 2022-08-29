`default_nettype none

module arst_sync (
    input        async_reset_i
  , input        clk_i
  , output logic sync_reset_o
);
  wire sync_dff1_lo;
  bsg_dff_async_reset #(
     .width_p(1)
    ,.reset_val_p(1)
  ) sync_dff1 (
     .clk_i(clk_i)
    ,.async_reset_i(async_reset_i)
    ,.data_i(1'b0)
    ,.data_o(sync_dff1_lo)
  );

  bsg_dff_async_reset #(
     .width_p(1)
    ,.reset_val_p(1)
  ) sync_dff2 (
     .clk_i(clk_i)
    ,.async_reset_i(async_reset_i)
    ,.data_i(sync_dff1_lo)
    ,.data_o(sync_reset_o)
  );
   

endmodule
