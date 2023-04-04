`ifndef BSG_WB_DEFINES_SVH
`define BSG_WB_DEFINES_SVH

  `define declare_bsg_wb_widths(addr_width_mp, data_width_mp) \
    , localparam wb_sel_width_lp     = data_width_mp >> 3 \
    , localparam wb_sel_width_log_lp = `BSG_SAFE_CLOG2(wb_sel_width_lp) \
    , localparam wb_adr_width_lp     = paddr_width_p - wb_sel_width_log_lp

`endif
