#include "bp_me_wb_master_ctrl.h"

#include <iostream>

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
    cmd_it = commands.begin();

    // generate commands
    for (int i = 0; i < test_size; i++) {
        uint8_t size = dice() & 0x3;
        uint64_t addr = dice() & 0xFFFFFFFFF8;
        uint8_t msg_type = 2 + (dice() & 0x1);
        uint64_t data = replicate(dice(), size);
        commands.emplace_back(size, addr, msg_type, data);
    }

    // create dpi_to_fifo and dpi_from_fifo objects
    d2f_cmd = std::make_unique<dpi_to_fifo<uint128_t>>("TOP.top.m_d2f_cmd");
    f2d_resp = std::make_unique<dpi_from_fifo<uint128_t>>("TOP.top.m_f2d_resp");
};

bool BP_me_WB_master_ctrl::sim_read() {
    // check for correct clock state
    if (f2d_resp->is_window()) {
        // check if adapter response is valid
        uint128_t command;
        if (f2d_resp->rx(command)) {
            
            if (responses.size() == test_size) {
                std::cout << "\nError: Master adapter received too many responses\n";
                return false;
            }

            uint64_t header = (command >> 64) & 0xFFFFFFFFFFFFFFFF;
            uint64_t data = command & 0xFFFFFFFFFFFFFFFF;
            responses.emplace_back(header, data);
        }
    }

    return true;
}

bool BP_me_WB_master_ctrl::sim_write() {
    // check for correct clock state
    if (d2f_cmd->is_window()) {
        uint128_t command = (static_cast<uint128_t>(cmd_it->header) << 64) | cmd_it->data;
        
        // try to send the command
        if (d2f_cmd->tx(command))
            cmd_it++;
    }

    return true;
}

uint64_t BP_me_WB_master_ctrl::replicate(uint64_t data, uint8_t size) {
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
