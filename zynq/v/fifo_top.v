
module fifo_top
 #(parameter C_S00_AXI_DATA_WIDTH = 32)
  (input wire                                    aclk
   , input wire                                  aresetn

   , input wire                                  s_axis_tvalid
   , input wire [C_S00_AXI_DATA_WIDTH-1:0]       s_axis_tdata
   , input wire [(C_S00_AXI_DATA_WIDTH/8)-1:0]   s_axis_tkeep
   , input wire                                  s_axis_tlast
   , output wire                                 s_axis_tready

   , output wire                                 m_axis_tvalid
   , output wire  [C_S00_AXI_DATA_WIDTH-1:0]     m_axis_tdata
   , output wire  [(C_S00_AXI_DATA_WIDTH/8)-1:0] m_axis_tkeep
   , output wire                                 m_axis_tlast
   , input wire                                  m_axis_tready
   );

  bsg_axis_fifo
   #(.C_S00_AXI_DATA_WIDTH(C_S00_AXI_DATA_WIDTH))
   fifo
    (.clk_i(aclk)
     ,.reset_i(!aresetn)

     ,.s_axis_tvalid_i(s_axis_tvalid)
     ,.s_axis_tdata_i(s_axis_tdata)
     ,.s_axis_tkeep_i(s_axis_tkeep)
     ,.s_axis_tlast_i(s_axis_tlast)
     ,.s_axis_tready_o(s_axis_tready)

     ,.m_axis_tvalid_o(m_axis_tvalid)
     ,.m_axis_tdata_o(m_axis_tdata)
     ,.m_axis_tkeep_o(m_axis_tkeep)
     ,.m_axis_tlast_o(m_axis_tlast)
     ,.m_axis_tready_i(m_axis_tready)
     );

endmodule

