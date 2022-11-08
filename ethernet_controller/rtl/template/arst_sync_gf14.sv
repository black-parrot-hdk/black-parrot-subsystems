
module arst_sync_harden (
    input        arst_i
  , input        bclk_i
  , output logic brst_o
);
  wire nreset = ~arst_i;
  wire nreset_synced;

  SC7P5T_SYNC2SDFFRQX2_SSC14L hard_sync_int
    (.D(1'b1)
    ,.CLK(bclk_i)
    ,.RESET(nreset)
    ,.SI(1'b0)
    ,.SE(1'b0)
    ,.Q(nreset_synced)
    );
  assign brst_o = ~nreset_synced;

endmodule
