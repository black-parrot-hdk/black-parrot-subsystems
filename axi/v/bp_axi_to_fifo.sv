/*
 * Name:
 *   bp_axi_to_fifo.sv
 *
 * Description:
 *   This module converts an AXI4 subordinate interface to a fifo interface. The independent
 *   read and write channels are serialized to the output fifo interface. Responses on the fifo
 *   interface must preserve ordering for reads and writes independently, but do not need to
 *   preserve the total read and write request order, as matches the AXI specification.
 *
 *   This module enforces a "one ID at a time" policy for both the AXI read and write channels.
 *   If a new AXI transaction arrives with an ID that differs from the current stream, the module
 *   will stall until all transactions with the previous ID receive responses.
 *
 *   The AXI interface has the following constraints:
 *   - data width of 64, 128, 256, 512, or 1024 bits
 *   - address width must be >= 32b, and preferrably 64b
 *   - all valid AXI transactions are supported
 *   - any value for AWID or ARID is allowed, but a change in ID causes the respective channel
 *     to stall until drained
 *
 *   The fifo interface uses the same address and data width as the AXI interface. The fifo
 *   interface will not interleave multi-transfer AXI transactions. The fifo client is
 *   responsible for enforcing any additional ordering among requests; this module adheres
 *   to the AXI ordering model. Every read and write on the fifo interface requires a response
 *
 */

`include "bsg_defines.v"

module bp_axi_to_fifo
 import bsg_axi_pkg::*;
 #(// AXI parameters
  parameter s_axi_data_width_p = 64
  , parameter s_axi_addr_width_p = 64
  , parameter s_axi_id_width_p = 1
  , localparam s_axi_mask_width_lp = s_axi_data_width_p>>3
  // Buffer sizes
  , parameter wr_els_p = 2
  , parameter wr_data_els_p = 2
  , parameter wr_resp_els_p = 2
  , parameter rd_els_p = 2
  , parameter rd_data_els_p = 2
  )
  (//==================== GLOBAL SIGNALS =======================
   input                                        clk_i
   , input                                      reset_i

   //==================== FIFO Interface =======================
   , output logic [s_axi_data_width_p-1:0]      data_o
   , output logic [s_axi_addr_width_p-1:0]      addr_o
   , output logic                               v_o
   , output logic                               w_o
   , output logic [s_axi_mask_width_lp-1:0]     wmask_o
   , output logic [2:0]                         size_o
   , input                                      yumi_i

   , input [s_axi_data_width_p-1:0]             data_i
   , input                                      v_i
   , input                                      w_i
   , output logic                               ready_and_o


   //====================== AXI-4 =========================
   , input [s_axi_addr_width_p-1:0]             s_axi_awaddr_i
   , input                                      s_axi_awvalid_i
   , output logic                               s_axi_awready_o
   , input [s_axi_id_width_p-1:0]               s_axi_awid_i
   , input                                      s_axi_awlock_i
   , input [3:0]                                s_axi_awcache_i
   , input [2:0]                                s_axi_awprot_i
   , input [7:0]                                s_axi_awlen_i
   , input [2:0]                                s_axi_awsize_i
   , input [1:0]                                s_axi_awburst_i
   , input [3:0]                                s_axi_awqos_i
   , input [3:0]                                s_axi_awregion_i

   , input [s_axi_data_width_p-1:0]             s_axi_wdata_i
   , input                                      s_axi_wvalid_i
   , output logic                               s_axi_wready_o
   , input                                      s_axi_wlast_i
   , input [s_axi_mask_width_lp-1:0]            s_axi_wstrb_i

   , output logic                               s_axi_bvalid_o
   , input                                      s_axi_bready_i
   , output logic [s_axi_id_width_p-1:0]        s_axi_bid_o
   , output logic [1:0]                         s_axi_bresp_o

   , input [s_axi_addr_width_p-1:0]             s_axi_araddr_i
   , input                                      s_axi_arvalid_i
   , output logic                               s_axi_arready_o
   , input [s_axi_id_width_p-1:0]               s_axi_arid_i
   , input                                      s_axi_arlock_i
   , input [3:0]                                s_axi_arcache_i
   , input [2:0]                                s_axi_arprot_i
   , input [7:0]                                s_axi_arlen_i
   , input [2:0]                                s_axi_arsize_i
   , input [1:0]                                s_axi_arburst_i
   , input [3:0]                                s_axi_arqos_i
   , input [3:0]                                s_axi_arregion_i

   , output logic [s_axi_data_width_p-1:0]      s_axi_rdata_o
   , output logic                               s_axi_rvalid_o
   , input                                      s_axi_rready_i
   , output logic [s_axi_id_width_p-1:0]        s_axi_rid_o
   , output logic                               s_axi_rlast_o
   , output logic [1:0]                         s_axi_rresp_o
   );

  // unused AXI interface signals
  wire aw_unused = &{s_axi_awlock_i, s_axi_awcache_i, s_axi_awprot_i
                     ,s_axi_awqos_i ,s_axi_awregion_i};
  wire ar_unused = &{s_axi_arlock_i, s_axi_arcache_i, s_axi_arprot_i
                     ,s_axi_arqos_i ,s_axi_arregion_i};

//==== AW and W management ====

  // AW channel input fifo
  // required to enforce ordering based on ID and keep
  // s_axi_awvalid_i decoupled from s_axi_awready_o
  logic s_axi_awvalid, s_axi_awyumi;
  logic [s_axi_addr_width_p-1:0] s_axi_awaddr;
  logic [s_axi_id_width_p-1:0] s_axi_awid;
  logic [7:0] s_axi_awlen;
  logic [2:0] s_axi_awsize;
  logic [1:0] s_axi_awburst;
  bsg_fifo_1r1w_small
    #(.width_p(s_axi_addr_width_p+s_axi_id_width_p+8+3+2)
      ,.els_p(2)
      )
    aw_fifo
     (.clk_i(clk_i)
      ,.reset_i(reset_i)
      ,.data_i({s_axi_awburst_i, s_axi_awsize_i, s_axi_awlen_i, s_axi_awid_i, s_axi_awaddr_i})
      ,.v_i(s_axi_awvalid_i)
      ,.ready_o(s_axi_awready_o)
      ,.data_o({s_axi_awburst, s_axi_awsize, s_axi_awlen, s_axi_awid, s_axi_awaddr})
      ,.v_o(s_axi_awvalid)
      ,.yumi_i(s_axi_awyumi)
      );

  // AW channel pump
  logic [s_axi_addr_width_p-1:0] awpump_addr_lo;
  logic [2:0] awpump_size_lo;
  logic awpump_last_lo;
  logic awpump_v_li, awpump_ready_and_lo, awpump_v_lo, awpump_send_li;
  bp_axi_pump
    #(.axi_addr_width_p(s_axi_addr_width_p)
      ,.axi_data_width_p(s_axi_data_width_p)
      )
    aw_pump
     (.clk_i(clk_i)
      ,.reset_i(reset_i)
      ,.v_i(awpump_v_li)
      ,.ready_and_o(awpump_ready_and_lo)
      ,.axaddr_i(s_axi_awaddr)
      ,.axburst_i(s_axi_awburst)
      ,.axlen_i(s_axi_awlen)
      ,.axsize_i(s_axi_awsize)
      ,.v_o(awpump_v_lo)
      ,.send_i(awpump_send_li)
      ,.addr_o(awpump_addr_lo)
      ,.mask_o() // mask comes from W channel
      ,.size_o(awpump_size_lo)
      ,.len_o() // unused
      ,.first_o() // unused
      ,.last_o(awpump_last_lo)
      );

  // AW ID fifo - one ID per AXI transaction
  // capture when pump accepts inputs, dequeue on last write response
  logic awid_v_li, awid_ready_and_lo;
  logic [s_axi_id_width_p-1:0] awid_li;
  logic awid_v_lo, awid_yumi_li;
  bsg_fifo_1r1w_small
    #(.width_p(s_axi_id_width_p)
      ,.els_p(wr_els_p)
      )
    awid_fifo
     (.clk_i(clk_i)
      ,.reset_i(reset_i)
      ,.data_i(s_axi_awid)
      ,.v_i(awid_v_li)
      ,.ready_o(awid_ready_and_lo)
      ,.data_o(awid_li)
      ,.v_o(awid_v_lo)
      ,.yumi_i(awid_yumi_li)
      );

  // handshake from aw fifo to AW Pump and AW ID fifo
  // block handshake if AW ID fifo ID out does not match AW fifo ID out
  wire block_aw_id = awid_v_lo & s_axi_awvalid & (awid_li == s_axi_awid);
  assign awpump_v_li = s_axi_awvalid & awid_ready_and_lo & ~block_aw_id;
  assign awid_v_li = s_axi_awvalid & awpump_ready_and_lo & ~block_aw_id;
  assign s_axi_awyumi = s_axi_awvalid & awpump_ready_and_lo & awid_ready_and_lo & ~block_aw_id;

  // W channel fifo
  logic wdata_valid_li, wdata_ready_and_lo;
  logic wdata_valid_lo, wdata_yumi_li;
  logic [s_axi_data_width_p-1:0] wdata_lo;
  logic [s_axi_mask_width_lp-1:0] wstrb_lo;
  bsg_fifo_1r1w_small
    #(.width_p(s_axi_data_width_p+s_axi_mask_width_lp)
      ,.els_p(wr_data_els_p)
      )
    wdata_fifo
     (.clk_i(clk_i)
      ,.reset_i(reset_i)
      ,.data_i({s_axi_wstrb_i, s_axi_wdata_i})
      ,.v_i(wdata_valid_li)
      ,.ready_o(wdata_ready_and_lo)
      ,.data_o({wstrb_lo, wdata_lo})
      ,.v_o(wdata_valid_lo)
      ,.yumi_i(wdata_yumi_li)
      );

  // W last fifo
  logic wlast_valid_lo, wlast_yumi_li;
  logic wlast_valid_li, wlast_ready_and_lo;
  logic wlast_lo;
  bsg_fifo_1r1w_small
    #(.width_p(1)
      ,.els_p(wr_resp_els_p)
      )
    wlast_fifo
     (.clk_i(clk_i)
      ,.reset_i(reset_i)
      ,.data_i(s_axi_wlast_i)
      ,.v_i(wlast_valid_li)
      ,.ready_o(wlast_ready_and_lo)
      ,.data_o(wlast_lo)
      ,.v_o(wlast_valid_lo)
      ,.yumi_i(wlast_yumi_li)
      );

  assign s_axi_wready_o = wdata_ready_and_lo & wlast_ready_and_lo;
  assign wdata_valid_li = s_axi_wvalid_i & wlast_ready_and_lo;
  assign wlast_valid_li = s_axi_wvalid_i & wdata_ready_and_lo;

//==== AR management ====

  // AR channel input fifo
  // required to enforce ordering based on ID and keep
  // s_axi_arvalid_i decoupled from s_axi_arready_o
  logic s_axi_arvalid, s_axi_aryumi;
  logic [s_axi_addr_width_p-1:0] s_axi_araddr;
  logic [s_axi_id_width_p-1:0] s_axi_arid;
  logic [7:0] s_axi_arlen;
  logic [2:0] s_axi_arsize;
  logic [1:0] s_axi_arburst;
  bsg_fifo_1r1w_small
    #(.width_p(s_axi_addr_width_p+s_axi_id_width_p+8+3+2)
      ,.els_p(2)
      )
    ar_fifo
     (.clk_i(clk_i)
      ,.reset_i(reset_i)
      ,.data_i({s_axi_arburst_i, s_axi_arsize_i, s_axi_arlen_i, s_axi_arid_i, s_axi_araddr_i})
      ,.v_i(s_axi_arvalid_i)
      ,.ready_o(s_axi_arready_o)
      ,.data_o({s_axi_arburst, s_axi_arsize, s_axi_arlen, s_axi_arid, s_axi_araddr})
      ,.v_o(s_axi_arvalid)
      ,.yumi_i(s_axi_aryumi)
      );

  // AR channel pump
  logic [s_axi_addr_width_p-1:0] arpump_addr_lo;
  logic [2:0] arpump_size_lo;
  logic arpump_last_lo;
  logic arpump_v_li, arpump_ready_and_lo, arpump_v_lo, arpump_send_li;
  bp_axi_pump
    #(.axi_addr_width_p(s_axi_addr_width_p)
      ,.axi_data_width_p(s_axi_data_width_p)
      )
    ar_pump
     (.clk_i(clk_i)
      ,.reset_i(reset_i)
      ,.v_i(arpump_v_li)
      ,.ready_and_o(arpump_ready_and_lo)
      ,.axaddr_i(s_axi_araddr)
      ,.axburst_i(s_axi_arburst)
      ,.axlen_i(s_axi_arlen)
      ,.axsize_i(s_axi_arsize)
      ,.v_o(arpump_v_lo)
      ,.send_i(arpump_send_li)
      ,.addr_o(arpump_addr_lo)
      ,.mask_o() // unused for reads
      ,.size_o(arpump_size_lo)
      ,.len_o() // unused
      ,.first_o() // unused
      ,.last_o(arpump_last_lo)
      );

  // AR ID fifo - one ID per AXI transaction
  // capture when pump accepts inputs, dequeue on last read response
  logic arid_v_li, arid_ready_and_lo;
  logic [s_axi_id_width_p-1:0] arid_li;
  logic arid_v_lo, arid_yumi_li;
  bsg_fifo_1r1w_small
    #(.width_p(s_axi_id_width_p)
      ,.els_p(rd_els_p)
      )
    arid_fifo
     (.clk_i(clk_i)
      ,.reset_i(reset_i)
      ,.data_i(s_axi_arid)
      ,.v_i(arid_v_li)
      ,.ready_o(arid_ready_and_lo)
      ,.data_o(arid_li)
      ,.v_o(arid_v_lo)
      ,.yumi_i(arid_yumi_li)
      );

  // handshake only if both AR Pump and AR ID FIFO can accept
  // block handshake if AR ID fifo ID out does not match AR fifo ID out
  wire block_ar_id = arid_v_lo & s_axi_arvalid & (arid_li == s_axi_arid);
  assign arpump_v_li = s_axi_arvalid & arid_ready_and_lo & ~block_ar_id;
  assign arid_v_li = s_axi_arvalid & arpump_ready_and_lo & ~block_ar_id;
  assign s_axi_aryumi = s_axi_arvalid & arpump_ready_and_lo & arid_ready_and_lo & ~block_ar_id;

  // R last fifo
  // enqueue from arpump
  logic rlast_valid_lo, rlast_yumi_li;
  logic rlast_valid_li, rlast_ready_and_lo;
  logic rlast_lo;
  bsg_fifo_1r1w_small
    #(.width_p(1)
      ,.els_p(rd_data_els_p)
      )
    rlast_fifo
     (.clk_i(clk_i)
      ,.reset_i(reset_i)
      ,.data_i(arpump_last_lo)
      ,.v_i(rlast_valid_li)
      ,.ready_o(rlast_ready_and_lo)
      ,.data_o(rlast_lo)
      ,.v_o(rlast_valid_lo)
      ,.yumi_i(rlast_yumi_li)
      );

  // Read request fifo between AR Pump and fifo_o to decouple interface from
  // AR Pump and rlast fifo
  logic rd_req_valid_lo, rd_req_yumi_li;
  logic rd_req_valid_li, rd_req_ready_and_lo;
  logic rd_req_last_lo;
  logic [2:0] rd_req_size_lo;
  logic [s_axi_addr_width_p-1:0] rd_req_addr_lo;
  bsg_fifo_1r1w_small
    #(.width_p(s_axi_addr_width_p+3+1)
      ,.els_p(2)
      )
    rd_req_fifo
     (.clk_i(clk_i)
      ,.reset_i(reset_i)
      ,.data_i({arpump_last_lo, arpump_size_lo, arpump_addr_lo})
      ,.v_i(rd_req_valid_li)
      ,.ready_o(rd_req_ready_and_lo)
      ,.data_o({rd_req_last_lo, rd_req_size_lo, rd_req_addr_lo})
      ,.v_o(rd_req_valid_lo)
      ,.yumi_i(rd_req_yumi_li)
      );

  // handshake from AR Pump to read request and rlast fifos
  assign rd_req_valid_li = arpump_v_lo & rlast_ready_and_lo;
  assign arpump_send_li = arpump_v_lo & rd_req_ready_and_lo & rlast_ready_and_lo;
  assign rlast_valid_li = arpump_v_lo & rd_req_ready_and_lo;


//==== fifo_o arbitration ====

  wire last_write = awpump_send_li & awpump_last_lo;
  wire last_read = rd_req_yumi_li & rd_req_last_lo;

  // FSM for sending on fifo interface
  typedef enum logic [1:0] {
    e_ready
    ,e_write
    ,e_read
  } state_e;
  state_e state_r, state_n;

  always_ff @(posedge clk_i) begin
    if (reset_i) begin
      state_r <= e_ready;
    end else begin
      state_r <= state_n;
    end
  end

  always_comb begin
    state_n = state_r;

    v_o = 1'b0;
    addr_o = '0;
    size_o = '0;
    w_o = 1'b0;
    data_o = '0;
    wmask_o = '0;

    case (state_r)
      // send first read or write transfer
      // if multi-transfer transaction, go to e_read or e_write
      // else block until last response sends
      e_ready: begin
        // priority to reads
        v_o = (awpump_v_lo & wdata_valid_lo) | rd_req_valid_lo;
        addr_o = rd_req_valid_lo ? rd_req_addr_lo : awpump_addr_lo;
        size_o = rd_req_valid_lo ? rd_req_size_lo : awpump_size_lo;
        w_o = awpump_v_lo & wdata_valid_lo & ~rd_req_valid_lo;
        data_o = w_o ? wdata_lo : '0;
        wmask_o = w_o ? wstrb_lo : '0;

        if (rd_req_yumi_li & ~rd_req_last_lo) begin
          state_n = e_read;
        end
        else if (awpump_send_li & ~awpump_last_lo) begin
          state_n = e_write;
        end
      end
      // handle multi-transfer writes
      e_write: begin
        v_o = awpump_v_lo & wdata_valid_lo;
        addr_o = awpump_addr_lo;
        size_o = awpump_size_lo;
        w_o = 1'b1;
        data_o = wdata_lo;
        wmask_o = wstrb_lo;
        state_n = last_write ? e_ready : state_r;
      end
      // handle multi-transfer reads
      e_read: begin
        v_o = rd_req_valid_lo;
        addr_o = rd_req_addr_lo;
        size_o = rd_req_size_lo;
        w_o = 1'b0;
        state_n = last_read ? e_ready : state_r;
      end
      default: begin
      end
    endcase
  end

  assign awpump_send_li = w_o & yumi_i;
  assign wdata_yumi_li = awpump_send_li;
  assign rd_req_yumi_li = ~w_o & yumi_i;

//==== fifo_i arbitration ====

  // write response fifo
  logic wr_resp_v_lo, wr_resp_yumi_li;
  logic wr_resp_ready_and_lo, wr_resp_v_li;
  bsg_fifo_1r1w_small
    #(.width_p(1)
      ,.els_p(wr_resp_els_p)
      )
    wr_resp_fifo
     (.clk_i(clk_i)
      ,.reset_i(reset_i)
      // from FIFO interface
      ,.v_i(wr_resp_v_li)
      ,.ready_o(wr_resp_ready_and_lo)
      ,.data_i(w_i)
      // to AXI
      ,.v_o(wr_resp_v_lo)
      ,.yumi_i(wr_resp_yumi_li)
      ,.data_o() // unused
      );

  // read response fifo
  logic rd_resp_v_lo, rd_resp_yumi_li;
  logic [s_axi_data_width_p-1:0] rd_resp_data_lo;
  logic rd_resp_ready_and_lo, rd_resp_v_li;
  bsg_fifo_1r1w_small
    #(.width_p(s_axi_data_width_p)
      ,.els_p(rd_data_els_p)
      )
    rd_resp_fifo
     (.clk_i(clk_i)
      ,.reset_i(reset_i)
      // from FIFO interface
      ,.v_i(rd_resp_v_li)
      ,.ready_o(rd_resp_ready_and_lo)
      ,.data_i(data_i)
      // to AXI
      ,.v_o(rd_resp_v_lo)
      ,.yumi_i(rd_resp_yumi_li)
      ,.data_o(rd_resp_data_lo)
      );

  assign ready_and_o = wr_resp_ready_and_lo & rd_resp_ready_and_lo;
  assign wr_resp_v_li = v_i & w_i & rd_resp_ready_and_lo;
  assign rd_resp_v_li = v_i & ~w_i & wr_resp_ready_and_lo;

//==== Write Response ====

  // B channel (write) response
  // send only one response for the entire write transaction

  wire bsend = s_axi_bvalid_o & s_axi_bready_i;
  wire b_fifos_v = wr_resp_v_lo & wlast_valid_lo & awid_v_lo;

  // send B when all fifos valid and last indicated
  assign s_axi_bvalid_o = b_fifos_v & wlast_lo;
  assign s_axi_bresp_o = e_axi_resp_okay;
  assign s_axi_bid_o = awid_li;

  // consume AW ID when B sends
  assign awid_yumi_li = bsend;
  // consume write response and last fifos when:
  // 1. all fifos valid and not last
  // 2. when B sends (on last)
  assign wr_resp_yumi_li = bsend | (b_fifos_v & ~wlast_lo);
  assign wlast_yumi_li = wr_resp_yumi_li;

//==== Read Response ====

  // R channel (read) response
  // send one response on AXI for every read issued to FIFO
  wire rsend = s_axi_rvalid_o & s_axi_rready_i;
  wire r_fifos_v = rd_resp_v_lo & rlast_valid_lo & arid_v_lo;

  // Send R for every read response when all fifos valid
  assign s_axi_rvalid_o = r_fifos_v;
  assign s_axi_rresp_o = e_axi_resp_okay;
  assign s_axi_rdata_o = rd_resp_data_lo;
  assign s_axi_rlast_o = rlast_lo;
  assign s_axi_rid_o = arid_li;

  // consume AR ID only on last transfer
  assign arid_yumi_li = rsend & rlast_lo;
  // consume read response and last fifos on every transfer
  assign rd_resp_yumi_li = rsend;
  assign rlast_yumi_li = rsend;

endmodule

