
/*
 * Memory map (compatible with the Litex Ethernet driver in Linux kernel 5.15):
 *   1. RX/TX Buffers (when eth_mtu_p == 0x800):
 *
 *     RX Buffer:
 *       0x0000-0x0800
 *     TX Buffer:
 *       0x0800-0x1000
 *
 *   2. Register Map:
 *
 *     Readable Register:
 *       0x1000: Index of the Received Packet      (a.k.a LITEETH_WRITER_SLOT)
 *       0x1004: Length of the Received Packet     (a.k.a LITEETH_WRITER_LENGTH)
 *       0x1010: RX Event Pending Bit              (a.k.a LITEETH_WRITER_EV_PENDING)
 *       0x101C: TX Ready Bit                      (a.k.a LITEETH_READER_READY)
 *       0x1030: TX Event Pending Bit              (a.k.a LITEETH_READER_EV_PENDING)
 *       0x1050: Debug Info                        (not compatible with Liteeth)
 *
 *     Writable Register:
 *       0x1010: RX Event Pending Bit              (a.k.a LITEETH_WRITER_EV_PENDING)
 *       0x1014: RX Event Enable Bit               (a.k.a LITEETH_WRITER_EV_ENABLE)
 *       0x1018: TX Send Bit                       (a.k.a LITEETH_READER_START)
 *       0x1024: Index of the Transmitting Packet  (a.k.a LITEETH_READER_SLOT)
 *       0x1028: Length of the Transmitting Packet (a.k.a LITEETH_READER_LENGTH)
 *       0x1030: TX Event Pending Bit              (a.k.a LITEETH_READER_EV_PENDING)
 *       0x1034: TX Event Enable Bit               (a.k.a LITEETH_READER_EV_ENABLE)
 *
 * Link:
 *   https://elixir.bootlin.com/linux/v5.15/source/drivers/net/ethernet/litex/litex_liteeth.c
 *
 */

`include "bsg_defines.v"


module ethernet_control_unit #
(
      parameter  eth_mtu_p            = 2048 // byte
    , parameter  data_width_p         = 32
    , localparam size_width_lp        = `BSG_WIDTH(`BSG_SAFE_CLOG2(data_width_p/8))
    , localparam packet_size_width_lp = $clog2(eth_mtu_p+1)
    , localparam packet_addr_width_lp = $clog2(eth_mtu_p)
    , localparam addr_width_lp        = 14
)
(
      input  bit                                clk_i
    , input  logic                              reset_i

    , input  logic [addr_width_lp-1:0]          addr_i
    , input  logic                              write_en_i
    , input  logic                              read_en_i
    , input  logic [size_width_lp-1:0]          op_size_i
    , input  logic [data_width_p-1:0]           write_data_i
    , output logic [data_width_p-1:0]           read_data_o // sync read

    , input  logic [15:0]                       debug_info_i

    , output logic                              packet_send_o
    , input  logic                              packet_req_i
    , output logic                              packet_wsize_valid_o
    , output logic [packet_size_width_lp-1:0]   packet_wsize_o
    , output logic                              packet_wvalid_o
    , output logic [packet_addr_width_lp-1:0]   packet_waddr_o
    , output logic [data_width_p-1:0]           packet_wdata_o
    , output logic [size_width_lp-1:0]          packet_wdata_size_o

    , output logic                              packet_ack_o
    , input  logic                              packet_avail_i
    , output logic                              packet_rvalid_o
    , output logic [packet_addr_width_lp-1:0]   packet_raddr_o
    , input  logic [data_width_p-1:0]           packet_rdata_i
    , input  logic [packet_size_width_lp-1:0]   packet_rsize_i

    , output logic                              tx_interrupt_clear_o

    , input  logic                              rx_interrupt_pending_i
    , input  logic                              tx_interrupt_pending_i
    , output logic                              rx_interrupt_enable_o
    , output logic                              rx_interrupt_enable_v_o
    , output logic                              tx_interrupt_enable_o
    , output logic                              tx_interrupt_enable_v_o
);

  logic buffer_read_v_r;
  logic [data_width_p-1:0] readable_reg_r, readable_reg_n;
  logic rx_interrupt_clear, tx_interrupt_clear;
  // Not used in this Ethernet controller, always points to 0
  logic tx_idx_r, tx_idx_n;
  logic io_decode_error;

  bsg_dff_reset_en
   #(.width_p(data_width_p + 2))
    registers
     (.clk_i(clk_i)
      ,.reset_i(reset_i)
      ,.en_i(read_en_i | write_en_i)
      ,.data_i({readable_reg_n, packet_rvalid_o, tx_idx_n})
      ,.data_o({readable_reg_r, buffer_read_v_r, tx_idx_r})
      );

  always_comb begin
    io_decode_error = 1'b0;
    packet_raddr_o = '0;
    packet_rvalid_o = 1'b0;

    packet_waddr_o = '0;
    packet_wdata_size_o = '0;
    packet_wdata_o = '0;
    packet_wvalid_o = 1'b0;

    readable_reg_n = '0;
    packet_send_o = 1'b0;
    tx_idx_n     = tx_idx_r;
    rx_interrupt_clear = 1'b0;
    tx_interrupt_clear = 1'b0;

    rx_interrupt_enable_o = 1'b0;
    rx_interrupt_enable_v_o = 1'b0;
    tx_interrupt_enable_o = 1'b0;
    tx_interrupt_enable_v_o = 1'b0;

    packet_wsize_o = '0;
    packet_wsize_valid_o = 1'b0;
    casez(addr_i)
      16'h0???: begin
        if(addr_i < 16'h0800) begin
          // RX buffer; R
          if(read_en_i) begin
            packet_raddr_o = addr_i[packet_addr_width_lp-1:0];
            packet_rvalid_o = 1'b1;
            io_decode_error = (op_size_i != $clog2(data_width_p/8));
          end
          if(write_en_i)
            io_decode_error = 1'b1;
        end
        else begin
          // TX buffer; W
          if(read_en_i)
            io_decode_error = 1'b1;
          if(write_en_i) begin
            packet_waddr_o = addr_i[packet_addr_width_lp-1:0];
            packet_wdata_size_o = op_size_i;
            packet_wdata_o = write_data_i;
            packet_wvalid_o = 1'b1;
          end
        end
      end
      16'h1000: begin
        // RX current slot index; R
        if(read_en_i)
          readable_reg_n  = '0; // always 0
        if(write_en_i)
          io_decode_error = 1'b1;
      end
      16'h1004: begin
        // RX received size; R
        if(read_en_i) begin
          if(packet_avail_i)
            readable_reg_n  = packet_rsize_i;
        end
        if(write_en_i)
          io_decode_error = 1'b1;
      end
      16'h1010: begin
        // RX EV Pending; RW
        if(read_en_i)
          readable_reg_n = rx_interrupt_pending_i;
        if(write_en_i) begin
          if(write_data_i[0] == 'b1) begin
            rx_interrupt_clear = 1'b1;
          end
        end
      end
      16'h1014: begin
        // RX EV Enable; W
        if(read_en_i)
          io_decode_error = 1'b1;
        if(write_en_i) begin
          rx_interrupt_enable_o = write_data_i[0];
          rx_interrupt_enable_v_o = 1'b1;
        end
      end
      16'h1018: begin
        // TX Send Bit; W
        if(read_en_i)
          io_decode_error = 1'b1;
        if(write_en_i)
          packet_send_o = 1'b1;
      end
      16'h101C: begin
        // TX Ready bit; R
        if(read_en_i)
          readable_reg_n = packet_req_i;
        if(write_en_i)
          io_decode_error = 1'b1;
      end
      16'h1024: begin
        // TX current slot index; W
        if(read_en_i)
          io_decode_error = 1'b1;
        if(write_en_i)
          tx_idx_n = write_data_i[0];
      end
      16'h1028: begin
        // TX size; W
        if(read_en_i)
          io_decode_error = 1'b1;
        if(write_en_i) begin
          packet_wsize_o = write_data_i;
          packet_wsize_valid_o = 1'b1;
        end
      end
      16'h1030: begin
        // TX Pending Bit; RW
        if(read_en_i)
          readable_reg_n = tx_interrupt_pending_i;
        if(write_en_i) begin
          if(write_data_i[0] == 'b1) begin
            // Generate a pulse signal for clear
            tx_interrupt_clear = 1'b1;
          end
        end
      end
      16'h1034: begin
        // TX Enable Bit; W
        if(read_en_i)
          io_decode_error = 1'b1;
        if(write_en_i) begin
          tx_interrupt_enable_o = write_data_i[0];
          tx_interrupt_enable_v_o = 1'b1;
        end
      end
      16'h1050: begin
        // Debug Info; R
        if(read_en_i)
          readable_reg_n = debug_info_i;
        if(write_en_i)
          io_decode_error = 1'b1;
      end

      default: begin
        // Unsupported MMIO
        if(read_en_i || write_en_i)
          io_decode_error = 1'b1;
      end
    endcase
    if(read_en_i & write_en_i)
      io_decode_error = 1'b1;
  end

  // Output can either come from RX buffer or registers
  assign read_data_o = buffer_read_v_r ? packet_rdata_i : readable_reg_r;

  assign packet_ack_o       = rx_interrupt_clear;
  assign tx_interrupt_clear_o = tx_interrupt_clear;

  // synopsys translate_off
  always_ff @(posedge clk_i) begin
    assert(reset_i !== 1'b0 || io_decode_error === 1'b0) else begin
      $error("%m: decode error at %t\n", $time);
      $finish;
    end
  end
  initial begin
    assert(eth_mtu_p <= 2048)
      else $error("ethernet_control_unit: eth_mtu_p should be <= 2048\n");
    assert(data_width_p == 32)
      else $error("ethernet_control_unit: unsupported data_width_p\n");
  end
  // synopsys translate_on

endmodule
