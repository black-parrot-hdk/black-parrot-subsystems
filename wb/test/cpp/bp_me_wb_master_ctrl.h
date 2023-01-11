#pragma once

#include "verilated.h"
#include "bsg_nonsynth_dpi_fifo.hpp"
#include "bp_pkg.h"

#include <vector>
#include <iterator>
#include <random>
#include <functional>
#include <memory>
#include <cstdint>

typedef unsigned __int128 uint128_t;

using namespace bsg_nonsynth_dpi;

class BP_me_WB_master_ctrl {
public:
    BP_me_WB_master_ctrl(
        int test_size,
        unsigned long seed
    );

    const std::vector<BP_pkg>& get_commands() {return commands;}
    const std::vector<BP_pkg>& get_responses() {return responses;}

    void sim_read();
    void sim_write();

    int get_progress() {return responses.size();}
    bool done() {return cmd_ind == commands.size() && responses.size() == test_size;}

private:
    std::unique_ptr<dpi_to_fifo<uint128_t>> d2f_cmd;
    bool d2f_cmd_init = false;
    std::unique_ptr<dpi_from_fifo<uint128_t>> f2d_resp;
    bool f2d_resp_init = false;

    int test_size;
    unsigned long seed;

    unsigned int rx_cooldown;
    unsigned int tx_cooldown;

    std::vector<BP_pkg> commands;
    int cmd_ind;
    int data_ind;
    std::vector<BP_pkg> responses;
    BP_pkg resp;

    std::default_random_engine generator;
    std::uniform_int_distribution<uint64_t> distribution;
    std::function<uint64_t()> dice;

    uint64_t replicate(uint64_t data, uint8_t size);
};
