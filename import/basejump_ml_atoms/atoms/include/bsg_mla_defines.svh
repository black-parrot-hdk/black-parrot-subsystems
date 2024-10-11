// BSD 3-Clause License
//
// Copyright (c) 2023, Bespoke Silicon Group
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are met:
//
// 1. Redistributions of source code must retain the above copyright notice, this
//    list of conditions and the following disclaimer.
//
// 2. Redistributions in binary form must reproduce the above copyright notice,
//    this list of conditions and the following disclaimer in the documentation
//    and/or other materials provided with the distribution.
//
// 3. Neither the name of the copyright holder nor the names of its
//    contributors may be used to endorse or promote products derived from
//    this software without specific prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
// AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
// IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
// DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
// FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
// DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
// SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
// CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
// OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
// OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

`ifndef __BSG_MLA_DEFINES__
`define __BSG_MLA_DEFINES__

`include "bsg_defines.sv"  // from basejump_stl/bsg_misc

////////////////////////////////////////
// Logging macros (BSG_MLA_LOG_*)
//

//`define BSG_MLA_LOG_NO_ERROR
//`define BSG_MLA_LOG_NO_WARN
//`define BSG_MLA_LOG_NO_INFO

`ifdef BSG_MLA_LOG_NO_ERROR
  `define BSG_MLA_LOG_ERROR(msg)
`else
  `define BSG_MLA_LOG_ERROR(msg) $display("[BSG-MLA ERROR %m @t=%0t] %s", $time, $sformatf(msg))
`endif

`ifdef BSG_MLA_LOG_NO_ERROR
  `define BSG_MLA_LOG_WARN(msg)
`else
  `define BSG_MLA_LOG_WARN(msg) $display("[BSG-MLA WARN %m @t=%0t] %s", $time, $sformatf(msg))
`endif

`ifdef BSG_MLA_LOG_NO_ERROR
  `define BSG_MLA_LOG_INFO(msg)
`else
  `define BSG_MLA_LOG_INFO(msg) $display("[BSG-MLA INFO %m @t=%0t] %s", $time, $sformatf(msg))
`endif

`endif // __BSG_MLA_DEFINES__
