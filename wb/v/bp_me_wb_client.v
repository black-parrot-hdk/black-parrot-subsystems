/**
 * bp_me_wb_client.v
 * DESCRIPTION: THIS MODULE ADAPTS BP MEMORY BUS TO 64-BIT WISHBONE FOR CLIENT DEVICES
 */

module bp_me_wb_client
  import bp_common_pkg::*;
  import bp_me_pkg::*;
  #(parameter bp_params_e bp_params_p = e_bp_default_cfg
    `declare_bp_proc_params(bp_params_p)
    `declare_bp_bedrock_mem_if_widths(paddr_width_p, did_width_p, lce_id_width_p, lce_assoc_p)

    , localparam wbone_addr_ubound   = paddr_width_p
    , localparam wbone_addr_lbound   = 3
    , localparam wbone_addr_width_lp = wbone_addr_ubound - wbone_addr_lbound
    , localparam wbone_data_width_lp = 64
    , localparam cached_addr_base_lp = 32'h8000_0000
   )
  (   input                                  clk_i
    , input                                  reset_i

    // BP side
    , input  [lce_id_width_p-1:0]            lce_id_i
    , input  [did_width_p-1:0]               did_i

    , output logic [mem_header_width_lp-1:0] mem_cmd_header_o
    , output logic [uce_fill_width_p-1:0]    mem_cmd_data_o
    , output logic                           mem_cmd_v_o
    , input                                  mem_cmd_ready_i

    , input  [mem_header_width_lp-1:0]       mem_resp_header_i
    , input  [uce_fill_width_p-1:0]          mem_resp_data_i
    , input                                  mem_resp_v_i
    , output logic                           mem_resp_yumi_o

    // Wishbone side
    , input  [wbone_data_width_lp-1:0]       dat_i
    , output logic [wbone_data_width_lp-1:0] dat_o
    , output logic                           ack_o
    , output logic                           err_o
    , input  [wbone_addr_width_lp-1:0]       adr_i 
    , input                                  stb_i
    , input                                  cyc_i
    , input  [7:0]                           sel_i
    , input                                  we_i
    , input  [2:0]                           cti_i
    , input  [1:0]                           bte_i
    , output logic                           rty_o
  );

  `declare_bp_bedrock_mem_if(paddr_width_p, did_width_p, lce_id_width_p, lce_assoc_p);
  `bp_cast_o(bp_bedrock_mem_header_s, mem_cmd_header);
  `bp_cast_i(bp_bedrock_mem_header_s, mem_resp_header);

  // one-hot state machine
  typedef enum {WAIT_CMD=3'b001, WAIT_READY=3'b010, WAIT_RESP=3'b100} state_t;
  state_t state;

  initial begin
    state = WAIT_CMD;
  end

  assign err_o = 0;
  assign rty_o = 0;
  
  // state machine implementing the handshaking
  always_ff @(posedge clk_i)
  begin
    if (reset_i) begin
      state <= WAIT_CMD;
      ack_o <= 0;
      mem_cmd_v_o <= 0;
      mem_resp_yumi_o <= 0;
    end
    else begin
      unique case (1'b1)
        state[0]:
          // WAIT_CMD
          begin
            // reset handshake signals
            ack_o <= 0;
            mem_resp_yumi_o <= 0;

            // check if cmd has been received
            if (stb_i && cyc_i) begin
              // check if the receiver is ready
              if (mem_cmd_ready_i) begin
                mem_cmd_v_o <= 1;

                // continue by waiting for resp
                state <= WAIT_RESP;
              end
              else
                state <= WAIT_READY;
            end
          end
        state[1]:
          // WAIT_READY
          begin
            // wait until the receiver is ready
            if (mem_cmd_ready_i) begin
              mem_cmd_v_o <= 1;

              // continue by waiting for resp
              state <= WAIT_RESP;
            end
          end
        state[2]:
          // WAIT_RESP
          begin
            // reset handshake signals
            mem_cmd_v_o <= 0;

            // check if resp has been received
            if (mem_resp_v_i) begin
              ack_o <= 1;
              mem_resp_yumi_o <= 1;

              // continue by wainting for cmd
              state <= WAIT_CMD;
            end
          end
      endcase
    end
  end

  /*
   * WB -> BP
   */
  // construct the header
  bp_bedrock_msg_size_e msg_size;
  logic [paddr_width_p-1:0] addr;
  always_comb begin
    // recover message size from sel_i
    unique case (sel_i)
      8'h01:
        begin
          msg_size = e_bedrock_msg_size_1;
          addr     = {adr_i, 3'b000};
        end
      8'h03:
        begin
          msg_size = e_bedrock_msg_size_2;
          addr     = {adr_i, 3'b000};
        end
      8'h0F:
        begin
          msg_size = e_bedrock_msg_size_4;
          addr     = {adr_i, 3'b000};
        end
      // 8'hFF:
      default:
        begin
          msg_size = e_bedrock_msg_size_8;
          addr     = {adr_i, 3'b000};
        end
    endcase

    mem_cmd_header_cast_o = '0;
    mem_cmd_header_cast_o.addr           = addr;
    mem_cmd_header_cast_o.size           = msg_size;
    mem_cmd_header_cast_o.payload.lce_id = lce_id_i;
    mem_cmd_header_cast_o.payload.did    = did_i;
    mem_cmd_header_cast_o.msg_type       = addr >= cached_addr_base_lp
      ? (we_i ? e_bedrock_mem_wr    : e_bedrock_mem_rd)     // ? 1 : 0
      : (we_i ? e_bedrock_mem_uc_wr : e_bedrock_mem_uc_rd); // ? 3 : 2
  end

  // replicate the data
  bsg_bus_pack
   #(.in_width_p(wbone_data_width_lp))
   bus_pack
    (  .data_i(dat_i)
      ,.sel_i('0)
      // bp_bedrock_msg_size_e uses the exact encoding we need here 
      ,.size_i(msg_size[1:0])
      ,.data_o(mem_cmd_data_o)
    );

  /*
   * BP -> WB
   */
  // store resp in local
  bp_bedrock_mem_header_s mem_resp_header_li;
  logic [uce_fill_width_p-1:0] mem_resp_data_li;
  bsg_dff_reset_en
  #(.width_p(mem_header_width_lp + uce_fill_width_p))
    mshr_reg
      (  .clk_i(clk_i)
        ,.reset_i(reset_i)
        ,.en_i(mem_resp_v_i)
        ,.data_i({mem_resp_header_i, mem_resp_data_i})
        ,.data_o({mem_resp_header_li, mem_resp_data_li})
      );
  
  // assign WB signals
  always_comb begin
    // dat_o
    dat_o = mem_resp_data_li;
  end
endmodule
