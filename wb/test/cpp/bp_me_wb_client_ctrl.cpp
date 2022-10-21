#include "bp_me_wb_client_ctrl.h"

#include <iostream>

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

        if (rx_cooldown == 0) {
            // check if adapter command is valid
            uint128_t command;
            if (f2d_cmd->rx(command)) {
                
                if (commands.size() == test_size) {
                    std::cout << "\nError: Client adapter received too many commands\n";
                    return false;
                }

                uint64_t header = (command >> 64);
                uint64_t data = command & 0xFFFFFFFFFFFFFFFF;
                commands.emplace_back(header, data);

                // construct a response with the same header
                uint64_t data_resp = replicate(dice(), 0);
                responses.emplace_back(header, data_resp);

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

        if (tx_cooldown == 0) {
            // try to send the response
            uint128_t response = (static_cast<uint128_t>(resp_it->header) << 64) | resp_it->data;
            if (d2f_resp->tx(response)) {
                resp_it++;
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
                    + ((data & 0xFF) << 8)
                    + ((data & 0xFF) << 16)
                    + ((data & 0xFF) << 24)
                    + ((data & 0xFF) << 32)
                    + ((data & 0xFF) << 40)
                    + ((data & 0xFF) << 48)
                    + ((data & 0xFF) << 56);
        case 1: return (data & 0xFFFF)
                    + ((data & 0xFFFF) << 16)
                    + ((data & 0xFFFF) << 32)
                    + ((data & 0xFFFF) << 48);
        case 2: return (data & 0xFFFFFFFF)
                    + ((data & 0xFFFFFFFF) << 32);
        default: return data;
    }
}
