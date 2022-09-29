#include "bp_me_wb_client_ctrl.h"

#include <iostream>

BP_me_WB_client_ctrl::BP_me_WB_client_ctrl(
    int test_size,
    unsigned long int seed,
    // BP command out
    VL_OUTW (&mem_cmd_header_o, 66, 0, 3),
    VL_OUT64(&mem_cmd_data_o, 63, 0),
    VL_OUT8 (&mem_cmd_v_o, 0, 0),
    VL_IN8  (&mem_cmd_ready_i, 0, 0),
    // BP response in
    VL_INW  (&mem_resp_header_i, 66, 0, 3),
    VL_IN64 (&mem_resp_data_i, 63, 0),
    VL_IN8  (&mem_resp_v_i, 0, 0),
    VL_OUT8 (&mem_resp_yumi_o, 0, 0)
) : test_size{test_size},
    generator{seed},
    dice{std::bind(distribution, generator)},
    mem_cmd_header_o{mem_cmd_header_o},
    mem_cmd_data_o{mem_cmd_data_o},
    mem_cmd_v_o{mem_cmd_v_o},
    mem_cmd_ready_i{mem_cmd_ready_i},
    mem_resp_header_i{mem_resp_header_i},
    mem_resp_data_i{mem_resp_data_i},
    mem_resp_v_i{mem_resp_v_i},
    mem_resp_yumi_o{mem_resp_yumi_o}
{
    commands.reserve(test_size);
    responses.reserve(test_size);

    resp_it = responses.begin();
};

bool BP_me_WB_client_ctrl::sim_read() {
    // check if command is ready
    if (mem_cmd_ready_i == 1 && mem_cmd_v_o == 1) {
        if (commands.size() == test_size) {
            std::cout << "\nError: Client adapter received too many commands\n";
            return false;
        }

        // read and save the incoming command
        commands.emplace_back(mem_cmd_header_o, mem_cmd_data_o);

        // construct the response
        VL_SIG64(data, 63, 0) = replicate(dice(), 0);
        responses.emplace_back(commands.back().header, data);

        ready_cooldown = dice() % 8;
    }

    return true;
}

bool BP_me_WB_client_ctrl::sim_write() {
    mem_cmd_ready_i = (ready_cooldown == 0);
    if (ready_cooldown > 0)
        ready_cooldown--;

    mem_resp_v_i = (resp_it != responses.end() && valid_cooldown == 0);
    if (valid_cooldown > 0)
        valid_cooldown--;

    // send the response if valid and the adapter is ready
    if (mem_resp_v_i == 1 && mem_resp_yumi_o == 1) {
        mem_resp_header_i = resp_it->header;
        mem_resp_data_i = resp_it->data;
        resp_it++;
    }

    return true;
}

VL_SIG64(, 63, 0) BP_me_WB_client_ctrl::replicate(VL_SIG64(data, 63, 0), VL_SIG8(size, 2, 0)) {
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
