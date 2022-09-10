`include "bsg_defines.v"

module bsg_store_and_forward #(
    parameter    `BSG_INV_PARAM(width_p)
)
(
    input                clk_i
    input                reset_i


input [width_p-1:0]        data_i
input                v_i
input                last_i
output logic            ready_and_o

output logic [width_p-1:0]    data_o
output logic            v_o
output logic            last_o
input                ready_and_i
);

endmodule

