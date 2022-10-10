#pragma once

#include "verilated.h"
#include "bp_packages.h"

#include <vector>
#include <iterator>
#include <random>
#include <functional>

class BP_me_WB_master_ctrl {
public:
    BP_me_WB_master_ctrl(
        int test_size,
        unsigned long int seed,
        VL_IN8  (&reset_i, 0, 0),
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
    );

    int get_progress() {return responses.size();}
    const std::vector<BP_cmd>& get_commands() {return commands;}
    const std::vector<BP_resp>& get_responses() {return responses;}

    bool sim_read();
    bool sim_write();

    bool done() {return responses.size() == test_size;}

private:
    VL_IN8  (&reset_i, 0, 0);
    VL_INW  (&mem_cmd_header_i, 66, 0, 3);
    VL_IN64 (&mem_cmd_data_i, 63, 0);
    VL_IN8  (&mem_cmd_v_i, 0, 0);
    VL_OUT8 (&mem_cmd_ready_o, 0, 0);
    VL_OUTW (&mem_resp_header_o, 66, 0, 3);
    VL_OUT64(&mem_resp_data_o, 63, 0);
    VL_OUT8 (&mem_resp_v_o, 0, 0);
    VL_IN8  (&mem_resp_yumi_i, 0, 0);

    int test_size;
    unsigned long int seed;

    int yumi_cooldown = 0;
    int valid_cooldown = 0;

    std::vector<BP_cmd> commands;
    std::vector<BP_cmd>::iterator cmd_it;
    std::vector<BP_resp> responses;

    std::default_random_engine generator;
    std::uniform_int_distribution<uint64_t> distribution;
    std::function<uint64_t()> dice;

    VL_SIG64(, 63, 0) replicate(VL_SIG64(data, 63, 0), VL_SIG8(size, 2, 0));
};
