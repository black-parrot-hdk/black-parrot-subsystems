
module bp_axi_cdl
  (input                                     core_clk_i
  ,input                                     core_reset_i

  ,input                                     ds_clk_i
  ,input                                     ds_reset_i

  ,input                                     en_i
  ,input [31:0]                              lat_i

  ,input                                     cmd_v_i
  ,input                                     resp_v_i
  ,output logic                              deq_o
  ,output logic                              gate_o
  );

  enum logic [3:0] {READY, BUSY, WFD, WFT} state_r, state_n;

  // Gated BP clk domain
  logic cnt_up_li, cnt_clr_li;
  logic [31:0] cnt_lo;
  wire start_li = en_i & cmd_v_i;
  wire end_lo = en_i & (cnt_lo == lat_i);
  assign cnt_clr_li = end_lo;

  bsg_dff_reset_en_bypass
   #(.width_p(1))
   i_cnt_up
   (.clk_i(core_clk_i)
   ,.reset_i(core_reset_i)
   ,.en_i(start_li | end_lo)
   ,.data_i(start_li)
   ,.data_o(cnt_up_li)
   );

  bsg_counter_clear_up
   #(.max_val_p(33'(2**32)-1))
   i_cnt
   (.clk_i(core_clk_i)
   ,.reset_i(core_reset_i)
   ,.clear_i(cnt_clr_li)
   ,.up_i(cnt_up_li)
   ,.count_o(cnt_lo)
   );

  // Ungated clk domain
  // FSM
  assign deq_o = en_i ? (state_n == READY) : 1'b1;
  wire gate_pos = en_i & (state_n == WFD);

  bsg_sync_sync
   #(.width_p(1))
   gate_bss
   (.oclk_i(~ds_clk_i)
   ,.iclk_data_i(gate_pos)
   ,.oclk_data_o(gate_o)
   );

  always_comb begin
    state_n = state_r;

    if(state_r == READY) begin
      state_n = (en_i & cmd_v_i) ? BUSY : READY;
    end
    else if(state_r == BUSY) begin
      if(resp_v_i & end_lo)
        state_n = READY;
      else if(resp_v_i)
        state_n = WFT;
      else if(end_lo)
        state_n = WFD;
    end
    else if(state_r == WFT) begin
      state_n = end_lo ? READY : WFT;
    end
    else if(state_r == WFD) begin
      state_n = resp_v_i ? READY : WFD;
    end
  end

  always_ff @(posedge ds_clk_i) begin
    if(ds_reset_i)
      state_r <= READY;
    else
      state_r <= state_n;
  end

endmodule
