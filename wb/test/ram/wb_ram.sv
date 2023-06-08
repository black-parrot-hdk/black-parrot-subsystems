module wb_ram
  #(  parameter  data_width_p = 64
    , parameter  ram_size_p   = 2**12
    , localparam word_size    = 8
    , localparam sel_width    = data_width_p / word_size
    , localparam adr_width    = $clog2(ram_size_p) - $clog2(sel_width)
  )
  (   input clk_i
    , input reset_i

    , input [adr_width-1:0]           adr_i
    , input [data_width_p-1:0]        dat_i
    , input                           cyc_i
    , input                           stb_i
    , input [sel_width-1:0]           sel_i
    , input                           we_i
    , input [2:0]                     cti_i
    , input [1:0]                     bte_i

    , output logic [data_width_p-1:0] dat_o
    , output logic                    ack_o
  );

  // memory array
  logic [(2**adr_width)-1:0][data_width_p-1:0] mem;
  integer i;
  initial begin
      for (i = 0; i < 2**adr_width; i = i + 1) begin
          mem[i] = '0;
      end
  end

  // detect if there's a burst access going on
  logic is_burst_r, is_burst_n;
  wire burst_start = cyc_i & stb_i
                     & ((cti_i == 3'b001) | (cti_i == 3'b010))
                     & !is_burst_r;
  wire burst_stop  = cyc_i & stb_i
                     & (cti_i == 3'b111)
                     & is_burst_r;

  logic [adr_width-1:0] adr_r, adr_n;
  logic ack_r, ack_n;
  wire burst_access_wrong_wb_adr = is_burst_r & (adr_r != adr_i);
  always_comb begin
    // check if burst is initiated or ended
    is_burst_n = is_burst_r;
    if (burst_start)
      is_burst_n = 1'b1;
    else if (burst_stop)
      is_burst_n = 1'b0;

    // calculate next address
    adr_n = adr_r;
    if (cyc_i & stb_i) begin
      if (is_burst_r)
        if (cti_i == 3'b001)
          // constant address burst
          adr_n = adr_r;
        else begin
          unique case (bte_i)
            // linear burst
            2'b00: adr_n      = adr_r      + 1;
            // 2 beat wrapped
            2'b01: adr_n[1:0] = adr_r[1:0] + 1;
            // 4 beat wrapped
            2'b10: adr_n[2:0] = adr_r[2:0] + 1;
            // 16 beat wrapped
            2'b11: adr_n[3:0] = adr_r[3:0] + 1;
            default: begin end
          endcase
        end
      else
        // no burst
        adr_n = adr_i;
    end

    // set ack
    ack_n = ack_r;
    if (cyc_i & stb_i) begin
      if (is_burst_r) begin
        ack_n = ~burst_stop;
      end
      else
        ack_n = ~ack_r;
    end

    // WB response
    ack_o = ack_r & !burst_access_wrong_wb_adr;
    dat_o = mem[adr_r];
  end

  always @(posedge clk_i) begin
    if (reset_i) begin
      is_burst_r <= '0;
      adr_r      <= '0;
      ack_r      <= '0;
    end
    else begin
      is_burst_r <= is_burst_n;
      adr_r      <= adr_n;
      ack_r      <= ack_n;
    end
  end

  // write logic
  always @ (posedge clk_i) begin
    for (i = 0; i < sel_width; i = i + 1) begin
      if (cyc_i & stb_i & ~reset_i) begin
        if (we_i & sel_i[i]) begin
          mem[adr_i][word_size*i +: word_size] <= dat_i[word_size*i +: word_size];
        end
      end
    end
  end
endmodule
