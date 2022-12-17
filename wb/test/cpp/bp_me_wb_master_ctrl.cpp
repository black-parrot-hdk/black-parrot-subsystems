#include "bp_me_wb_master_ctrl.h"

#include <iostream>
#include <cstring>

using namespace bsg_nonsynth_dpi;

BP_me_WB_master_ctrl::BP_me_WB_master_ctrl(
    int test_size,
    unsigned long int seed
) : test_size{test_size},
    generator{seed},
    dice{std::bind(distribution, generator)}
{
    commands.reserve(test_size);
    responses.reserve(test_size);

    // construct commands
    for (int i = 0; i < test_size; i++) {
        BP_pkg cmd;
        cmd.header = dice();

        // only certain values are allowed
        cmd.msg_type = 0b0010 + (cmd.msg_type & 0b0001);
        cmd.subop = 0;
        cmd.addr = cmd.addr & 0x7FFFFFFFF8;
        cmd.size = cmd.size % 4;
        cmd.payload = 0;

        // generate data
        std::vector<uint64_t> data;
        if (cmd.msg_type == 0b10) {
            // read commands only require one transfer
            data.push_back(replicate(dice(), cmd.size));
        } else {
            // write commands might require multiple transfers
            int bits = (1 << cmd.size) * 8;
            int transfers = bits / 64 + (bits < 64);
            for (int j = 0; j < transfers; j++)
                data.push_back(replicate(dice(), cmd.size));
        }
        cmd.data = std::move(data);
        commands.push_back(std::move(cmd));

    }

    cmd_it = commands.begin();
    data_it = cmd_it->data.begin();

    d2f_cmd = std::make_unique<dpi_to_fifo<uint128_t>>("TOP.top.m_d2f_cmd");
    f2d_resp = std::make_unique<dpi_from_fifo<uint128_t>>("TOP.top.m_f2d_resp");

    rx_cooldown = dice() % 16;
    tx_cooldown = dice() % 16;
};

bool BP_me_WB_master_ctrl::sim_read() {
    if (f2d_resp->is_window()) {

        // init the rx fifo
        if (!f2d_resp_init) {
            svScope prev = svSetScope(svGetScopeFromName("TOP.top.m_f2d_resp"));
            bsg_dpi_init();
            svSetScope(prev);
            f2d_resp_init = true;
        }

        // read the response
        if (rx_cooldown == 0) {
            uint128_t response;
            if (f2d_resp->rx(response)) {
                
                // error if we receive a new response but have already received enough responses
                if (resp.data.empty() && responses.size() == test_size) {
                    std::cout << "\nError: Master adapter received too many responses\n";
                    return false;
                }

                // the highest bit of the header holds 'last' bit
                uint64_t header = response >> 64;
                bool last = header & 0x8000000000000000;
                resp.header = header & ~0x8000000000000000;
                resp.data.push_back(response & 0xFFFFFFFFFFFFFFFF);

                if (last) {
                    responses.push_back(resp);
                    resp.data.clear();
                }

                rx_cooldown = dice() % 16;
            }
        } else {
            rx_cooldown--;
        }
    }

    return true;
}

bool BP_me_WB_master_ctrl::sim_write() {
    if (d2f_cmd->is_window() && cmd_it != commands.end()) {

        // init the tx fifo
        if (!d2f_cmd_init) {
            svScope prev = svSetScope(svGetScopeFromName("TOP.top.m_d2f_cmd"));
            bsg_dpi_init();
            svSetScope(prev);
            d2f_cmd_init = true;
        }

        // send the command
        if (tx_cooldown == 0) {
            bool last = data_it + 1 == cmd_it->data.end();

            // construct the command and set or clear the 'last' bit if required
            uint128_t command = cmd_it->header;
            if (last)
                command |= 0x8000000000000000;
            else
                command &= ~0x8000000000000000;
            command = command << 64 | *data_it;

            // try to send and adjust the iterators if successful
            if (d2f_cmd->tx(command)) {
                if (last) {
                    cmd_it++;
                    data_it = cmd_it->data.begin();
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

uint64_t BP_me_WB_master_ctrl::replicate(uint64_t data, uint8_t size) {
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
