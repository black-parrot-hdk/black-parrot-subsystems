
`include "bsg_defines.sv"

module bsg_axis_fifo
 #(parameter C_S00_AXI_DATA_WIDTH = 32)
  (input                                          clk_i
   , input                                        reset_i

   , input                                        s_axis_tvalid_i
   , input [C_S00_AXI_DATA_WIDTH-1:0]             s_axis_tdata_i
   , input [(C_S00_AXI_DATA_WIDTH/8)-1:0]         s_axis_tkeep_i
   , input                                        s_axis_tlast_i
   , output logic                                 s_axis_tready_o

   , output logic                                 m_axis_tvalid_o
   , output logic  [C_S00_AXI_DATA_WIDTH-1:0]     m_axis_tdata_o
   , output logic  [(C_S00_AXI_DATA_WIDTH/8)-1:0] m_axis_tkeep_o
   , output logic                                 m_axis_tlast_o
   , input                                        m_axis_tready_i
   );

  enum logic {e_rx, e_tx} state_n, state_r;
  wire is_rx = state_r inside {e_rx};
  wire is_tx = state_r inside {e_tx};

  localparam max_els_lp = 128;

  logic [`BSG_WIDTH(max_els_lp)-1:0] tx_count_lo;
  bsg_counter_up_down
   #(.max_val_p(max_els_lp), .init_val_p(0), .max_step_p(1))
   bcud
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.up_i(s_axis_tready_o & s_axis_tvalid_i)
     ,.down_i(m_axis_tready_i & m_axis_tvalid_o)
     ,.count_o(tx_count_lo)
     );

  logic fifo_ready_lo, fifo_v_lo;
  assign s_axis_tready_o = is_rx & fifo_ready_lo;
  bsg_fifo_1r1w_small
   #(.width_p(C_S00_AXI_DATA_WIDTH), .els_p(max_els_lp), .ready_THEN_valid_p(1))
   fifo
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.data_i(s_axis_tdata_i)
     ,.v_i(s_axis_tready_o & s_axis_tvalid_i)
     ,.ready_param_o(fifo_ready_lo)

     ,.data_o(m_axis_tdata_o)
     ,.v_o(fifo_v_lo)
     ,.yumi_i(m_axis_tready_i & m_axis_tvalid_o)
     );
  assign m_axis_tvalid_o = is_tx & fifo_v_lo;
  assign m_axis_tkeep_o = '1;
  assign m_axis_tlast_o = (tx_count_lo == 1'b1);

  always_comb
    case (state_r)
      e_rx: state_n = (s_axis_tready_o & s_axis_tvalid_i & s_axis_tlast_i) ? e_tx : state_r;
      e_tx: state_n = (m_axis_tready_i & m_axis_tvalid_o & m_axis_tlast_o) ? e_rx : state_r;
    endcase

  // synopsys sync_set_reset "reset_i"
  always_ff @(posedge clk_i)
    if (reset_i)
      state_r <= e_rx;
    else
      state_r <= state_n;

endmodule

