#include "bp_me_wb_master_ctrl.h"

#include <iostream>

BP_me_WB_master_ctrl::BP_me_WB_master_ctrl(
    int test_size,
    unsigned long int seed,
    // BP command in
    VL_INW  (&mem_cmd_header_i, 66, 0, 3),
    VL_IN64 (&mem_cmd_data_i, 63, 0),
    VL_IN8  (&mem_cmd_v_i, 0, 0),
    VL_OUT8 (&mem_cmd_ready_o, 0, 0),
    // BP response out
    VL_OUTW (&mem_resp_header_o, 66, 0, 3),
    VL_OUT64(&mem_resp_data_o, 63, 0),
    VL_OUT8 (&mem_resp_v_o, 0, 0),
    VL_IN8  (&mem_resp_yumi_i, 0, 0)
) : test_size{test_size},
    generator{seed},
    dice{std::bind(distribution, generator)},
    mem_cmd_header_i{mem_cmd_header_i},
    mem_cmd_data_i{mem_cmd_data_i},
    mem_cmd_v_i{mem_cmd_v_i},
    mem_cmd_ready_o{mem_cmd_ready_o},
    mem_resp_header_o{mem_resp_header_o},
    mem_resp_data_o{mem_resp_data_o},
    mem_resp_v_o{mem_resp_v_o},
    mem_resp_yumi_i{mem_resp_yumi_i}
{
    commands.reserve(test_size);
    responses.reserve(test_size);

    cmd_it = commands.begin();

    // generate commands
    for (int i = 0; i < test_size; i++) {
        VL_SIG8(size, 2, 0) = dice() & 0x3;
        VL_SIG64(addr, 39, 0) = dice() & 0xFFFFFFFFF8;
        VL_SIG8(msg_type, 3, 0) = 2 + (dice() & 0x1);
        VL_SIG64(data, 63, 0) = replicate(dice(), size);
        commands.emplace_back(size, addr, msg_type, data);
    }
};

bool BP_me_WB_master_ctrl::sim_read() {
    // check if response is ready
    if (mem_resp_v_o == 1 && mem_resp_yumi_i == 1) {
        if (responses.size() == test_size) {
            std::cout << "\nError: Master adapter received too many responses\n";
            return false;
        }

        // read and save the response
        responses.emplace_back(mem_resp_header_o, mem_resp_data_o);

        yumi_cooldown = dice() % 8;
    }

    return true;
}

bool BP_me_WB_master_ctrl::sim_write() {
    mem_cmd_v_i = (cmd_it != commands.end() && (valid_cooldown == 0));
    if (valid_cooldown > 0)
        valid_cooldown--;

    mem_resp_yumi_i = (mem_resp_v_o == 1 && (yumi_cooldown == 0));
    if (yumi_cooldown > 0)
        yumi_cooldown--;

    // send the next command if valid and the adapter is ready
    if (mem_cmd_v_i == 1 && mem_cmd_ready_o == 1) {
        mem_cmd_header_i = cmd_it->header;
        mem_cmd_data_i = cmd_it->data;
        cmd_it++;

        valid_cooldown = dice() % 8;
    }

    return true;
}

VL_SIG64(, 63, 0) BP_me_WB_master_ctrl::replicate(VL_SIG64(data, 63, 0), VL_SIG8(size, 2, 0)) {
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
