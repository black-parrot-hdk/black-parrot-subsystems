// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

module dmidpi #(
  parameter string Name = "dmi0", // name of the interface (display only)
  parameter int ListenPort = 44853 // TCP port to listen on
)(
  input  bit        clk_i,
  input  bit        rst_ni,

  output bit        dmi_req_valid,
  input  bit        dmi_req_ready,
  output bit [6:0]  dmi_req_addr,
  output bit [1:0]  dmi_req_op,
  output bit [31:0] dmi_req_data,
  input  bit        dmi_rsp_valid,
  output bit        dmi_rsp_ready,
  input  bit [31:0] dmi_rsp_data,
  input  bit [1:0]  dmi_rsp_resp,
  output bit        dmi_rst_n
);

  import "DPI-C"
  function chandle dmidpi_create(input string name, input int listen_port);

  import "DPI-C"
  function void dmidpi_tick(input chandle ctx, output bit dmi_req_valid,
                            input bit dmi_req_ready, output bit [6:0] dmi_req_addr,
                            output bit [1:0] dmi_req_op, output bit [31:0] dmi_req_data,
                            input bit dmi_rsp_valid, output bit dmi_rsp_ready,
                            input bit [31:0] dmi_rsp_data, input bit [1:0] dmi_rsp_resp,
                            output bit dmi_rst_n);

  import "DPI-C"
  function void dmidpi_close(input chandle ctx);

  chandle ctx;

  initial begin
    @(posedge rst_ni);
    ctx = dmidpi_create(Name, ListenPort);
  end

  final begin
    dmidpi_close(ctx);
    ctx = null;
  end

  bit        __dmi_req_valid;
  bit        __dmi_req_ready;
  bit [6:0]  __dmi_req_addr;
  bit [1:0]  __dmi_req_op;
  bit [31:0] __dmi_req_data;
  bit        __dmi_rsp_ready;
  bit        __dmi_rst_n;

  bit [31:0] __dmi_rsp_data;
  bit [1:0]  __dmi_rsp_resp;

  assign __dmi_req_ready = dmi_req_ready;
  assign __dmi_rsp_valid = dmi_rsp_valid;
  assign __dmi_rsp_resp  = dmi_rsp_resp;
  assign __dmi_rsp_data  = dmi_rsp_data;

  always_ff @(posedge clk_i) begin
    dmi_req_valid <= __dmi_req_valid;
    dmi_req_addr <= __dmi_req_addr;
    dmi_req_op <= __dmi_req_op;
    dmi_req_data <= __dmi_req_data;
    dmi_rsp_ready <= __dmi_rsp_ready;
    dmi_rst_n <= __dmi_rst_n;
  end

  always_ff @(negedge clk_i) begin
    if (!rst_ni) begin
        __dmi_req_valid <= 0;
        __dmi_rsp_ready <= 0;
    end else begin
        dmidpi_tick(ctx, __dmi_req_valid, __dmi_req_ready, __dmi_req_addr, __dmi_req_op,
                    __dmi_req_data, __dmi_rsp_valid, __dmi_rsp_ready, __dmi_rsp_data,
                    __dmi_rsp_resp, __dmi_rst_n);
    end
  end

endmodule
