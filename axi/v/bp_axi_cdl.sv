
module bp_axi_cdl
  (input                                     ungated_clk_i
  ,input                                     ungated_reset_i

  ,input                                     gate_i
  ,input                                     gate_en_i
  ,input [31:0]                              dram_lat_i
  ,output logic                              gate_o

  ,input                                     cmd_v_i
  ,input                                     resp_v_i
  ,output logic                              deq_o
  );

  // Gated BP clk domain
  logic cnt_up_li, cnt_clr_li;
  logic [31:0] cnt_lo;
  wire start_li = gate_en_i & cmd_v_i;
  wire end_lo = gate_en_i & (cnt_lo == dram_lat_i);

  bsg_dff_reset_en_bypass
   #(.width_p(1))
   i_cnt_up
   (.clk_i(ungated_clk_i)
   ,.reset_i(ungated_reset_i)
   ,.en_i(start_li | end_lo)
   ,.data_i(~end_lo)
   ,.data_o(cnt_up_li)
   );

  bsg_counter_clear_up
   #(.max_val_p(33'(2**32)-1))
   i_cnt
   (.clk_i(ungated_clk_i)
   ,.reset_i(ungated_reset_i)
   ,.clear_i(cnt_clr_li)
   ,.up_i(cnt_up_li & ~gate_i)
   ,.count_o(cnt_lo)
   );

  // Ungated clk domain
  // FSM
  enum logic [3:0] {INIT, WFD, WFT, DEQ} state_r, state_n;

  assign cnt_clr_li = (state_r == DEQ);
  assign deq_o = gate_en_i ? (state_r == DEQ) : 1'b1;
  assign gate_o = gate_en_i & (state_r == WFD);

  always_comb begin
    state_n = state_r;

   if(state_r == INIT) begin
      if(~gate_en_i)
        state_n = cmd_v_i ? WFD : INIT;
      else begin
        state_n = end_lo ? WFD : (resp_v_i ? WFT : INIT);
      end
   end
   else if (state_r == WFD) begin
     state_n = resp_v_i
               ? DEQ
               : WFD;
   end
   else if (state_r == WFT) begin
     state_n = end_lo
               ? DEQ
               : WFT;
   end
   else if (state_r == DEQ) begin
     state_n = resp_v_i
               ? DEQ
               : INIT;
   end
  end

  always_ff @(posedge ungated_clk_i) begin
    if(ungated_reset_i)
      state_r <= INIT;
    else
      state_r <= state_n;
  end
endmodule
