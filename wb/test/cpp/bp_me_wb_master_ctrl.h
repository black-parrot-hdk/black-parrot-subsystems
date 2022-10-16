#pragma once

#include "verilated.h"
#include "bsg_nonsynth_dpi_fifo.hpp"
#include "bp_packages.h"

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
        unsigned long int seed
    );

    int get_progress() {return responses.size();}
    const std::vector<BP_cmd>& get_commands() {return commands;}
    const std::vector<BP_resp>& get_responses() {return responses;}

    bool sim_read();
    bool sim_write();

    bool done() {return responses.size() == test_size;}

private:
    std::unique_ptr<dpi_to_fifo<uint128_t>> d2f_cmd_header;
    std::unique_ptr<dpi_to_fifo<uint64_t>> d2f_cmd_data;

    std::unique_ptr<dpi_from_fifo<uint128_t>> f2d_resp_header;
    std::unique_ptr<dpi_from_fifo<uint64_t>> f2d_resp_data;

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

    uint64_t replicate(uint64_t data, uint8_t size);
};
