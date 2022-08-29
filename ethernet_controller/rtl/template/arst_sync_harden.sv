`default_nettype none

module arst_sync_harden (
    input        async_reset_i
  , input        clk_i
  , output logic sync_reset_o
);
  wire nreset = ~async_reset_i;
  wire nreset_synced;

  SC7P5T_SYNC2SDFFRQX2_SSC14L hard_sync_int
    (.D(1'b0)
    ,.CLK(clk_i)
    ,.RESET(nreset)
    ,.SI(1'b0)
    ,.SE(1'b0)
    ,.Q(nreset_synced)
    );
  assign sync_reset_o = ~nreset_synced;

endmodule
