
#ifndef BSG_ZYNQ_UART_H
#define BSG_ZYNQ_UART_H

  typedef union {
    struct {
      uint32_t data : 32;
      uint32_t addr30to2 : 30;
      uint8_t wr_not_rd : 1;
      uint8_t port : 1;
    } __attribute__((packed, aligned(8))) f;
    uint64_t bits;
  } bsg_zynq_uart_pkt_t;

#endif
