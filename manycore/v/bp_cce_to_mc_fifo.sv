
`include "bp_common_defines.svh"

module bp_cce_to_mc_fifo
 import bp_common_pkg::*;
 import bsg_manycore_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)
   `declare_bp_bedrock_mem_if_widths(paddr_width_p, did_width_p, lce_id_width_p, lce_assoc_p)

   , parameter `BSG_INV_PARAM(x_cord_width_p)
   , parameter `BSG_INV_PARAM(y_cord_width_p)
   , parameter `BSG_INV_PARAM(data_width_p)
   , parameter `BSG_INV_PARAM(addr_width_p)
   , parameter `BSG_INV_PARAM(icache_block_size_in_words_p)

   , localparam mc_link_sif_width_lp = `bsg_manycore_link_sif_width(addr_width_p, data_width_p, x_cord_width_p, y_cord_width_p)
   )
  (input                                        clk_i
   , input                                      reset_i

   , input [mem_fwd_header_width_lp-1:0]        mem_fwd_header_i
   , input [bedrock_fill_width_p-1:0]           mem_fwd_data_i
   , input                                      mem_fwd_v_i
   , output logic                               mem_fwd_ready_and_o

   , output logic [mem_rev_header_width_lp-1:0] mem_rev_header_o
   , output logic [bedrock_fill_width_p-1:0]    mem_rev_data_o
   , output logic                               mem_rev_v_o
   , input                                      mem_rev_ready_and_i

   , input [mc_link_sif_width_lp-1:0]           link_sif_i
   , output logic [mc_link_sif_width_lp-1:0]    link_sif_o

   , input [x_cord_width_p-1:0]                 global_x_i
   , input [y_cord_width_p-1:0]                 global_y_i
   );

  `declare_bp_bedrock_mem_if(paddr_width_p, did_width_p, lce_id_width_p, lce_assoc_p);
  `declare_bp_memory_map(paddr_width_p, daddr_width_p);
  `declare_bsg_manycore_packet_s(addr_width_p, data_width_p, x_cord_width_p, y_cord_width_p);
  `bp_cast_i(bp_bedrock_mem_fwd_header_s, mem_fwd_header);
  `bp_cast_o(bp_bedrock_mem_rev_header_s, mem_rev_header);

  // TODO: This should be set in bsg_replicant
  typedef struct packed
  {
    logic [15:0] reserved;
    logic [31:0] addr;
    logic [7:0]  op_v2;
    logic [7:0]  reg_id;
    logic [31:0] payload;
    logic [7:0]  y_src;
    logic [7:0]  x_src;
    logic [7:0]  y_dst;
    logic [7:0]  x_dst;
  }  host_request_packet_s;

  typedef struct packed
  {
    logic [63:0] reserved;
    logic [7:0]  op_v2;
    logic [31:0] payload;
    logic [7:0]  reg_id;
    logic [7:0]  y_dst;
    logic [7:0]  x_dst;
  }  host_response_packet_s;

  localparam mc_link_bp_req_fifo_addr_gp     = 20'h0_0100;
  localparam mc_link_bp_req_credits_addr_gp  = 20'h0_0200;
  localparam mc_link_bp_resp_fifo_addr_gp    = 20'h0_0300;
  localparam mc_link_bp_resp_entries_addr_gp = 20'h0_0400;
  localparam mc_link_mc_req_fifo_addr_gp     = 20'h0_0500;
  localparam mc_link_mc_req_entries_addr_gp  = 20'h0_0600;

  bp_bedrock_mem_fwd_header_s mem_fwd_header_li;
  logic [bedrock_fill_width_p-1:0] mem_fwd_data_li;
  logic mem_fwd_v_li, mem_fwd_yumi_lo;
  bsg_two_fifo
   #(.width_p($bits(bp_bedrock_mem_fwd_header_s)+bedrock_fill_width_p))
   header_fifo
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.data_i({mem_fwd_data_i, mem_fwd_header_cast_i})
     ,.v_i(mem_fwd_v_i)
     ,.ready_o(mem_fwd_ready_and_o)

     ,.data_o({mem_fwd_data_li, mem_fwd_header_li})
     ,.v_o(mem_fwd_v_li)
     ,.yumi_i(mem_fwd_yumi_lo)
     );
  wire [dev_addr_width_gp-1:0] dev_addr_li = mem_fwd_header_li.addr;

  logic                                 in_v_lo;
  logic [data_width_p-1:0]              in_data_lo;
  logic [(data_width_p>>3)-1:0]         in_mask_lo;
  logic [addr_width_p-1:0]              in_addr_lo;
  logic                                 in_we_lo;
  bsg_manycore_load_info_s              in_load_info_lo;
  logic [x_cord_width_p-1:0]            in_src_x_cord_lo;
  logic [y_cord_width_p-1:0]            in_src_y_cord_lo;
  logic                                    in_yumi_li;

  logic [data_width_p-1:0]              returning_data_li;
  logic                                    returning_v_li;

  logic                                    out_v_li;
  bsg_manycore_packet_s                    out_packet_li;
  logic                                    out_ready_lo;

  logic [data_width_p-1:0]              returned_data_r_lo;
  logic [bsg_manycore_reg_id_width_gp-1:0] returned_reg_id_r_lo;
  logic                                    returned_v_r_lo, returned_yumi_li;
  bsg_manycore_return_packet_type_e        returned_pkt_type_r_lo;
  logic                                    returned_fifo_full_lo;
  logic                                    returned_credit_v_r_lo;
  logic [bsg_manycore_reg_id_width_gp-1:0] returned_credit_reg_id_r_lo;

  logic [5:0]                              out_credits_used_lo;

  bsg_manycore_endpoint_standard
   #(.x_cord_width_p(x_cord_width_p)
     ,.y_cord_width_p(y_cord_width_p)
     ,.data_width_p(data_width_p)
     ,.addr_width_p(addr_width_p)
     ,.icache_block_size_in_words_p(icache_block_size_in_words_p)
     ,.fifo_els_p(4)
     )
   blackparrot_endpoint
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.link_sif_i(link_sif_i)
     ,.link_sif_o(link_sif_o)

     //--------------------------------------------------------
     // 1. in_request signal group
     ,.in_v_o(in_v_lo)
     ,.in_data_o(in_data_lo)
     ,.in_mask_o(in_mask_lo)
     ,.in_addr_o(in_addr_lo)
     ,.in_we_o(in_we_lo)
     ,.in_load_info_o(in_load_info_lo)
     ,.in_src_x_cord_o(in_src_x_cord_lo)
     ,.in_src_y_cord_o(in_src_y_cord_lo)
     ,.in_yumi_i(in_yumi_li)

     //--------------------------------------------------------
     // 2. out_response signal group
     //    responses that will send back to the network
     ,.returning_data_i(returning_data_li)
     ,.returning_v_i(returning_v_li)

     //--------------------------------------------------------
     // 3. out_request signal group
     //    request that will send to the network
     ,.out_v_i(out_v_li)
     ,.out_packet_i(out_packet_li)
     ,.out_credit_or_ready_o(out_ready_lo)

     //--------------------------------------------------------
     // 4. in_response signal group
     //    responses that send back from the network
     //    the node shold always be ready to receive this response.
     ,.returned_data_r_o(returned_data_r_lo)
     ,.returned_reg_id_r_o(returned_reg_id_r_lo)
     ,.returned_v_r_o(returned_v_r_lo)
     ,.returned_pkt_type_r_o(returned_pkt_type_r_lo)
     ,.returned_yumi_i(returned_yumi_li)
     ,.returned_fifo_full_o()

     ,.returned_credit_v_r_o(returned_credit_v_r_lo)
     ,.returned_credit_reg_id_r_o(returned_credit_reg_id_r_lo)

     ,.out_credits_used_o(out_credits_used_lo)

     ,.global_x_i(global_x_i)
     ,.global_y_i(global_y_i)
     );
  
  //////////////////////////////////////////////
  // Host Interface
  //////////////////////////////////////////////
  logic bp_to_mc_v_li, bp_to_mc_ready_lo;
  host_request_packet_s bp_to_mc_lo;
  logic bp_to_mc_v_lo, bp_to_mc_yumi_li;

  host_response_packet_s mc_to_bp_response_li;
  logic mc_to_bp_response_v_li, mc_to_bp_response_ready_lo;
  logic [bedrock_fill_width_p-1:0] mc_to_bp_response_data_lo;
  logic mc_to_bp_response_v_lo, mc_to_bp_response_yumi_li;

  host_request_packet_s mc_to_bp_request_li;
  logic mc_to_bp_request_v_li, mc_to_bp_request_ready_lo;
  logic [bedrock_fill_width_p-1:0] mc_to_bp_request_data_lo;
  logic mc_to_bp_request_v_lo, mc_to_bp_request_yumi_li;

  bsg_manycore_packet_s bp_to_mc_out_packet_li;
  wire [bedrock_fill_width_p-1:0] bp_to_mc_data_li = mem_fwd_data_li[0+:bedrock_fill_width_p];
  bsg_serial_in_parallel_out_full
    #(.width_p(bedrock_fill_width_p), .els_p($bits(host_request_packet_s)/bedrock_fill_width_p))
    bp_to_mc_request_sipo
     (.clk_i(clk_i)
       ,.reset_i(reset_i)
 
       ,.data_i(bp_to_mc_data_li)
       ,.v_i(bp_to_mc_v_li)
       ,.ready_o(bp_to_mc_ready_lo)
 
       ,.data_o(bp_to_mc_lo)
       ,.v_o(bp_to_mc_v_lo)
       ,.yumi_i(bp_to_mc_yumi_li)
       );
  assign bp_to_mc_out_packet_li = '{addr       : bp_to_mc_lo.addr
                                    ,op_v2     : bsg_manycore_packet_op_e'(bp_to_mc_lo.op_v2)
                                    ,reg_id    : bp_to_mc_lo.reg_id
                                    ,payload   : bp_to_mc_lo.payload
                                    ,src_y_cord: bp_to_mc_lo.y_src
                                    ,src_x_cord: bp_to_mc_lo.x_src
                                    ,y_cord    : bp_to_mc_lo.y_dst
                                    ,x_cord    : bp_to_mc_lo.x_dst
                                    };

  bsg_parallel_in_serial_out
    #(.width_p(bedrock_fill_width_p), .els_p($bits(host_response_packet_s)/bedrock_fill_width_p))
    mc_to_bp_response_piso
    (.clk_i(clk_i)
      ,.reset_i(reset_i)

      ,.data_i(mc_to_bp_response_li)
      ,.valid_i(mc_to_bp_response_v_li)
      ,.ready_and_o(mc_to_bp_response_ready_lo)

      ,.data_o(mc_to_bp_response_data_lo)
      ,.valid_o(mc_to_bp_response_v_lo)
      ,.yumi_i(mc_to_bp_response_yumi_li)
      );
  // We ignore the x dst and y dst of return packets
  // TODO: Support remote SW
  assign mc_to_bp_response_li = '{x_dst   : global_x_i
                                  ,y_dst  : global_y_i
                                  ,reg_id : returned_reg_id_r_lo
                                  ,payload: returned_data_r_lo
                                  ,op_v2  : returned_pkt_type_r_lo
                                  ,default: '0
                                  };

  bsg_parallel_in_serial_out
    #(.width_p(bedrock_fill_width_p), .els_p($bits(host_request_packet_s)/bedrock_fill_width_p))
    mc_to_bp_request_piso
    (.clk_i(clk_i)
      ,.reset_i(reset_i)

      ,.data_i(mc_to_bp_request_li)
      ,.valid_i(mc_to_bp_request_v_li)
      ,.ready_and_o(mc_to_bp_request_ready_lo)

      ,.data_o(mc_to_bp_request_data_lo)
      ,.valid_o(mc_to_bp_request_v_lo)
      ,.yumi_i(mc_to_bp_request_yumi_li)
      );
  assign mc_to_bp_request_v_li = in_v_lo;
  // TODO: Only support stores? Add loads too
  assign mc_to_bp_request_li = '{x_dst    : global_x_i
                                  ,y_dst   : global_y_i
                                  ,x_src   : in_src_x_cord_lo
                                  ,y_src   : in_src_y_cord_lo
                                  ,payload : in_data_lo
                                  ,reg_id  : in_mask_lo
                                  ,op_v2   : in_we_lo ? e_remote_store : e_remote_load
                                  ,addr    : in_addr_lo
                                  ,default : '0
                                  };

  //////////////////////////////////////////////
  // Outgoing Request
  //////////////////////////////////////////////
  always_comb
    begin
      mem_rev_header_cast_o = mem_fwd_header_li;
      mem_rev_data_o = '0;
      mem_rev_v_o = '0;
      mem_fwd_yumi_lo = '0;

      bp_to_mc_v_li = '0;
      bp_to_mc_yumi_li = '0;
      mc_to_bp_request_yumi_li = '0;
      mc_to_bp_response_yumi_li = '0;

      out_packet_li = '0;
      out_v_li = '0;

      mc_to_bp_response_v_li = '0;
      returned_yumi_li = '0;

      if (mem_fwd_v_li && dev_addr_li == mc_link_bp_req_fifo_addr_gp)
        begin
          mem_rev_data_o = '0;
          mem_rev_v_o    = bp_to_mc_ready_lo;
          mem_fwd_yumi_lo = mem_rev_ready_and_i & mem_rev_v_o;

          bp_to_mc_v_li  = mem_fwd_yumi_lo;
        end
      else if (mem_fwd_v_li && dev_addr_li == mc_link_bp_req_credits_addr_gp)
        begin
          mem_rev_data_o = out_credits_used_lo;
          mem_rev_v_o    = 1'b1;
          mem_fwd_yumi_lo = mem_rev_ready_and_i & mem_rev_v_o;
        end
      else if (mem_fwd_v_li && dev_addr_li == mc_link_bp_resp_fifo_addr_gp)
        begin
          mem_rev_data_o = mc_to_bp_response_data_lo;
          mem_rev_v_o    = mc_to_bp_response_v_lo;
          mem_fwd_yumi_lo = mem_rev_ready_and_i & mem_rev_v_o;

          mc_to_bp_response_yumi_li = mem_fwd_yumi_lo;
        end
      else if (mem_fwd_v_li && dev_addr_li == mc_link_bp_resp_entries_addr_gp)
        begin
          mem_rev_data_o = mc_to_bp_response_v_lo;
          mem_rev_v_o    = 1'b1;
          mem_fwd_yumi_lo = mem_rev_ready_and_i & mem_rev_v_o;
        end
      else if (mem_fwd_v_li && dev_addr_li == mc_link_mc_req_fifo_addr_gp)
        begin
          mem_rev_data_o = mc_to_bp_request_data_lo;
          mem_rev_v_o    = 1'b1;
          mem_fwd_yumi_lo = mem_rev_ready_and_i & mem_rev_v_o;

          mc_to_bp_request_yumi_li = mem_fwd_yumi_lo;
        end
      else if (mem_fwd_v_li && dev_addr_li == mc_link_mc_req_entries_addr_gp)
        begin
          mem_rev_data_o = mc_to_bp_request_v_lo;
          mem_rev_v_o    = 1'b1;
          mem_fwd_yumi_lo = mem_rev_ready_and_i & mem_rev_v_o;
        end

        // MC Response
        mc_to_bp_response_v_li = returned_v_r_lo;
        returned_yumi_li = mc_to_bp_response_ready_lo & mc_to_bp_response_v_li;

        // BP Request
        bp_to_mc_yumi_li = out_ready_lo & bp_to_mc_v_lo;
        out_v_li = bp_to_mc_yumi_li;
        out_packet_li = bp_to_mc_out_packet_li;
    end

  //////////////////////////////////////////////
  // Incoming packet
  //////////////////////////////////////////////
  assign in_yumi_li = in_v_lo & mc_to_bp_request_ready_lo;

  // Always return the next cycle
  always_ff @(posedge clk_i)
    returning_v_li <= in_yumi_li;
  assign returning_data_li = '0;

endmodule
