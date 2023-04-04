package bsg_wb_pkg;
  typedef enum logic [2:0]
  {
     e_wb_classic_cycle    = 3'b000
    ,e_wb_const_addr_burst = 3'b001
    ,e_wb_inc_addr_burst   = 3'b010
    ,e_wb_end_of_burst     = 3'b011
  } bsg_wb_cti;

  typedef enum logic [1:0]
  {
     e_wb_linear_burst       = 2'b00
    ,e_wb_4_beat_wrap_burst  = 2'b01
    ,e_wb_8_beat_wrap_burst  = 2'b10
    ,e_wb_16_beat_wrap_burst = 2'b11
  } bsg_wb_bte;
endpackage
