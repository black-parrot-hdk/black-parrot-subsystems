#include "bp_me_wb_client_ctrl.h"

#include <iostream>
#include <cstring>

using namespace bsg_nonsynth_dpi;

BP_me_WB_client_ctrl::BP_me_WB_client_ctrl(
    int test_size,
    unsigned long seed
) : test_size{test_size},
    generator{seed},
    dice{std::bind(distribution, generator)}
{
    commands.reserve(test_size);
    responses.reserve(test_size);
    resp_ind = 0;

    f2d_cmd = std::make_unique<dpi_from_fifo<uint128_t>>("TOP.top.c_f2d_cmd");
    d2f_resp = std::make_unique<dpi_to_fifo<uint128_t>>("TOP.top.c_d2f_resp");

    rx_cooldown = dice() % 16;
    tx_cooldown = dice() % 16;
};

void BP_me_WB_client_ctrl::sim_read() {
    // init the rx fifo
    if (!f2d_cmd_init) {
        svScope prev = svSetScope(svGetScopeFromName("TOP.top.c_f2d_cmd"));
        bsg_dpi_init();
        svSetScope(prev);
        f2d_cmd_init = true;
    }

    if (f2d_cmd->is_window()) {
        // read the command
        // it is assumed, that the client adapter
        // always outputs single beat commands
        if (rx_cooldown == 0) {
            uint128_t command;
            if (f2d_cmd->rx(command)) {

                cmd.header = command >> 64;
                cmd.data.push_back(command & 0xFFFFFFFFFFFFFFFF);
                commands.push_back(cmd);
                cmd.data.clear();

                // construct a response with the same header
                BP_pkg resp;
                resp.header = cmd.header;

                // generate response data
                std::vector<uint64_t> resp_data;
                resp_data.push_back(replicate(dice(), resp.size));
                resp.data = std::move(resp_data);

                responses.push_back(std::move(resp));
                rx_cooldown = dice() % 16;
            }
        } else {
            --rx_cooldown;
        }
    }
}

void BP_me_WB_client_ctrl::sim_write() {
    // init the tx fifo
    if (!d2f_resp_init) {
        svScope prev = svSetScope(svGetScopeFromName("TOP.top.c_d2f_resp"));
        bsg_dpi_init();
        svSetScope(prev);
        d2f_resp_init = true;
    }

    if (d2f_resp->is_window() && resp_ind < responses.size()) {
        // send the response
        if (tx_cooldown == 0) {

            // construct the response assuming that the
            // response only needs one transmission
            uint128_t response = responses[resp_ind].header;
            response = response << 64 | responses[resp_ind].data.front();

            // try to send
            if (d2f_resp->tx(response)) {
                ++resp_ind;
                tx_cooldown = dice() % 16;
            }
        } else {
            --tx_cooldown;
        }
    }
}

uint64_t BP_me_WB_client_ctrl::replicate(uint64_t data, uint8_t size) {
    // for BP, less than bus width data must be replicated
    switch (size) {
        case 0: return (data & 0xFF)
                    | ((data & 0xFF) << 8)
                    | ((data & 0xFF) << 16)
                    | ((data & 0xFF) << 24)
                    | ((data & 0xFF) << 32)
                    | ((data & 0xFF) << 40)
                    | ((data & 0xFF) << 48)
                    | ((data & 0xFF) << 56);
        case 1: return (data & 0xFFFF)
                    | ((data & 0xFFFF) << 16)
                    | ((data & 0xFFFF) << 32)
                    | ((data & 0xFFFF) << 48);
        case 2: return (data & 0xFFFFFFFF)
                    | ((data & 0xFFFFFFFF) << 32);
        default: return data;
    }
}
