/**
 * bp_me_wb_master.v
 * DESCRIPTION: THIS MODULE ADAPTS BP MEMORY BUS TO 64-BIT WISHBONE FOR MASTER DEVICES
 */

module bp_me_wb_master
  import bp_common_pkg::*;
  import bp_me_pkg::*;
  #(parameter bp_params_e bp_params_p = e_bp_default_cfg
    `declare_bp_proc_params(bp_params_p)
    `declare_bp_bedrock_mem_if_widths(paddr_width_p, did_width_p, lce_id_width_p, lce_assoc_p)

    , localparam wbone_addr_ubound   = paddr_width_p
    , localparam wbone_addr_lbound   = 3
    , localparam wbone_addr_width_lp = wbone_addr_ubound - wbone_addr_lbound
    , localparam wbone_data_width_lp = 64
  )
  (   input                                  clk_i
    , input                                  reset_i

    // BP side
    , input  [mem_header_width_lp-1:0]       mem_cmd_header_i
    , input  [uce_fill_width_p-1:0]          mem_cmd_data_i
    , input                                  mem_cmd_v_i
    , output logic                           mem_cmd_ready_o

    , output logic [mem_header_width_lp-1:0] mem_resp_header_o
    , output logic [uce_fill_width_p-1:0]    mem_resp_data_o
    , output logic                           mem_resp_v_o
    , input                                  mem_resp_yumi_i

    // Wishbone side
    , input  [wbone_data_width_lp-1:0]       dat_i
    , output logic [wbone_data_width_lp-1:0] dat_o
    , input                                  ack_i
    , input                                  err_i
    , output logic [wbone_addr_width_lp-1:0] adr_o
    , output logic                           stb_o
    , output logic                           cyc_o
    , output logic [7:0]                     sel_o
    , output logic                           we_o
    , output logic [2:0]                     cti_o
    , output logic [1:0]                     bte_o
    , input                                  rty_i
  );

  `declare_bp_bedrock_mem_if(paddr_width_p, did_width_p, lce_id_width_p, lce_assoc_p);
  //`bp_cast_i(bp_bedrock_mem_header_s, mem_cmd_header);
  //`bp_cast_o(bp_bedrock_mem_header_s, mem_resp_header);

  // one-hot state machine
  typedef enum {WAIT_CMD=2'b01, WAIT_RESP=2'b10} state_t;
  state_t state;

  assign cti_o = 0;
  assign bte_o = 0;
  
  initial begin
    state = WAIT_CMD;
  end

  // state machine implementing the handshaking
  always_ff @(posedge clk_i) begin
    if (reset_i) begin
      state <= WAIT_CMD;
      stb_o <= 0;
      cyc_o <= 0;
      mem_cmd_ready_o <= 1;
      mem_resp_v_o <= 0;
    end
    else begin
      unique case (1'b1)
        state[0]:
          // WAIT_CMD
          begin
            // only allow for new commands after the response is consumed
            mem_resp_v_o <= mem_resp_v_o & !mem_resp_yumi_i;
            mem_cmd_ready_o <= !mem_resp_v_o & !mem_cmd_v_i;

            // check if cmd has been received
            if (mem_cmd_v_i) begin
              stb_o <= 1;
              cyc_o <= 1;

              // continue by wainting for resp
              state <= WAIT_RESP;
            end
          end
        state[1]:
          // WAIT_RESP
          begin
            // check if resp has been received
            if (ack_i) begin
              // reset handshake signals
              stb_o <= 0;
              cyc_o <= 0;

              mem_resp_v_o <= 1;

              // continue by wainting for cmd
              state <= WAIT_CMD;
            end
          end
      endcase
    end
  end

  /*
   * BP -> WB
   */
  // store cmd header and data
  bp_bedrock_mem_header_s mem_cmd_header_li;
  logic [uce_fill_width_p-1:0] mem_cmd_data_li;
  bsg_dff_reset_en
  #(.width_p(mem_header_width_lp + uce_fill_width_p))
    cmd_header_dff
      (  .clk_i(clk_i)
        ,.reset_i(reset_i)
        ,.en_i(mem_cmd_v_i)
        ,.data_i({mem_cmd_header_i, mem_cmd_data_i})
        ,.data_o({mem_cmd_header_li, mem_cmd_data_li})
      );

  // assign WB signals
  always_comb begin
    // dat_o
    dat_o = mem_cmd_data_li;
    
    // adr_o
    adr_o = mem_cmd_header_li.addr[wbone_addr_ubound-1:wbone_addr_lbound];

    // sel_o
    unique case (mem_cmd_header_li.size)
      e_bedrock_msg_size_1: sel_o = 8'h01;
      e_bedrock_msg_size_2: sel_o = 8'h03;
      e_bedrock_msg_size_4: sel_o = 8'h0F;
      // e_bedrock_msg_size_8:
      default: sel_o = 8'hFF;
    endcase

    // we_o
    we_o = mem_cmd_header_li.msg_type inside {e_bedrock_mem_uc_wr, e_bedrock_mem_wr}
      ? '1
      : '0;
  end

  /*
   * WB -> BP
   */
  bsg_bus_pack
   #(.in_width_p(wbone_data_width_lp))
   bus_pack
    (  .data_i(dat_i)
      ,.sel_i('0)
      // bp_bedrock_msg_size_e uses the exact encoding we need here 
      ,.size_i(mem_cmd_header_li.size[1:0])
      ,.data_o(mem_resp_data_o)
    );
  
  always_comb begin
    mem_resp_header_o = mem_cmd_header_li;
  end
endmodule
