
module arst_sync (
    input        arst_i
  , input        bclk_i
  , output logic brst_o
);

  (* ASYNC_REG = "TRUE" *)
  logic [0:0] bsg_SYNC_1_r, bsg_SYNC_2_r;
  always @(posedge bclk_i or posedge arst_i) begin
    if(arst_i)
      bsg_SYNC_1_r <= 1'b1;
    else
      bsg_SYNC_1_r <= 1'b0;
  end
  always @(posedge bclk_i or posedge arst_i) begin
    if(arst_i)
      bsg_SYNC_2_r <= 1'b1;
    else
      bsg_SYNC_2_r <= bsg_SYNC_1_r;
  end
  assign brst_o = bsg_SYNC_2_r[0];
endmodule
