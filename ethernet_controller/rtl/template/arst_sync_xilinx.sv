
module arst_sync (
    input        async_reset_i
  , input        clk_i
  , output logic sync_reset_o
);
/*
  wire sync_dff1_lo;
  bsg_dff_async_reset #(
     .width_p(1)
    ,.reset_val_p(1)
  ) bsg_SYNC_1_r (
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
*/
  (* ASYNC_REG = "TRUE" *)
  logic [0:0] bsg_SYNC_1_r, bsg_SYNC_2_r;
  always @(posedge clk_i or posedge async_reset_i) begin
    if(async_reset_i)
      bsg_SYNC_1_r <= 1'b1;
    else
      bsg_SYNC_1_r <= 1'b0;
  end
  always @(posedge clk_i or posedge async_reset_i) begin
    if(async_reset_i)
      bsg_SYNC_2_r <= 1'b1;
    else
      bsg_SYNC_2_r <= bsg_SYNC_1_r;
  end
  assign sync_reset_o = bsg_SYNC_2_r[0];
endmodule
