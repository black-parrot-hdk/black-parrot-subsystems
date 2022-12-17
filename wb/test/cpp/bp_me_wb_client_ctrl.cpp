#include "bp_me_wb_client_ctrl.h"

#include <iostream>
#include <cstring>

using namespace bsg_nonsynth_dpi;

BP_me_WB_client_ctrl::BP_me_WB_client_ctrl(
    int test_size,
    unsigned long int seed
) : test_size{test_size},
    generator{seed},
    dice{std::bind(distribution, generator)}
{
    commands.reserve(test_size);
    responses.reserve(test_size);
    resp_it = responses.begin();

    f2d_cmd = std::make_unique<dpi_from_fifo<uint128_t>>("TOP.top.c_f2d_cmd");
    d2f_resp = std::make_unique<dpi_to_fifo<uint128_t>>("TOP.top.c_d2f_resp");

    rx_cooldown = dice() % 16;
    tx_cooldown = dice() % 16;
};

bool BP_me_WB_client_ctrl::sim_read() {
    if (f2d_cmd->is_window()) {

        // init the rx fifo
        if (!f2d_cmd_init) {
            svScope prev = svSetScope(svGetScopeFromName("TOP.top.c_f2d_cmd"));
            bsg_dpi_init();
            svSetScope(prev);
            f2d_cmd_init = true;
        }

        // read the command
        if (rx_cooldown == 0) {
            uint128_t command;
            if (f2d_cmd->rx(command)) {

                // the highest bit of the header holds 'last' bit
                uint64_t header = command >> 64;
                bool last = header & 0x8000000000000000;
                cmd.header = header & ~0x8000000000000000;
                cmd.data.push_back(command & 0xFFFFFFFFFFFFFFFF);

                if (last) {
                    commands.push_back(cmd);
                    cmd.data.clear();
                }

                // construct a response with the same header
                BP_pkg resp;
                resp.header = cmd.header;

                // generate response data
                std::vector<uint64_t> data;
                if (cmd.msg_type == 0b10) {
                    // read commands might require multiple transfers
                    int bits = (1 << cmd.size) * 8;
                    int transfers = bits / 64 + (bits < 64);
                    for (int j = 0; j < transfers; j++)
                        data.push_back(replicate(dice(), resp.size));
                } else {
                    // write responses only require one transfer
                    data.push_back(replicate(dice(), resp.size));
                }
                resp.data = std::move(data);
                responses.push_back(std::move(resp));
                data_it = resp_it->data.begin();

                rx_cooldown = dice() % 16;
            }
        } else {
            rx_cooldown--;
        }
    }

    return true;
}

bool BP_me_WB_client_ctrl::sim_write() {
    if (d2f_resp->is_window() && resp_it != responses.end()) {

        // init the tx fifo
        if (!d2f_resp_init) {
            svScope prev = svSetScope(svGetScopeFromName("TOP.top.c_d2f_resp"));
            bsg_dpi_init();
            svSetScope(prev);
            d2f_resp_init = true;
        }

        // send the response
        if (tx_cooldown == 0) {
            bool last = data_it + 1 == resp_it->data.end();

            // construct the response and set or clear the 'last' bit if required
            uint128_t response = resp_it->header;
            if (last)
                response |= 0x8000000000000000;
            else
                response &= ~0x8000000000000000;
            response = response << 64 | *data_it;

            // try to send and adjust the iterators if successful
            if (d2f_resp->tx(response)) {
                if (last) {
                    resp_it++;
                    data_it = resp_it->data.begin();
                } else {
                    data_it++;
                }

                tx_cooldown = dice() % 16;
            }
        } else {
            tx_cooldown--;
        }
    }

    return true;
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
