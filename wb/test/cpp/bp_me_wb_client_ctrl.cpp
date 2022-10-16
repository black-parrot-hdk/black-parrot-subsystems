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

    // create dpi_to_fifo and dpi_from_fifo objects
    f2d_cmd_header =
        std::make_unique<dpi_from_fifo<unsigned __int128>>("TOP.top.c_f2d_cmd_header");
    f2d_cmd_data =
        std::make_unique<dpi_from_fifo<uint64_t>>("TOP.top.c_f2d_cmd_data");
    d2f_resp_header =
        std::make_unique<dpi_to_fifo<unsigned __int128>>("TOP.top.c_d2f_resp_header");
    d2f_resp_data =
        std::make_unique<dpi_to_fifo<uint64_t>>("TOP.top.c_d2f_resp_data");
};

bool BP_me_WB_client_ctrl::sim_read() {
    unsigned __int128 header;
    uint64_t data;

    // check for correct clock state
    if (f2d_cmd_header->is_window()) {

        // check if adapter command is valid
        if (f2d_cmd_header->rx(header)) {
            // also read the data
            f2d_cmd_data->rx(data);
            
            if (commands.size() == test_size) {
                std::cout << "\nError: Client adapter received too many commands\n";
                return false;
            }
            commands.emplace_back(header, data);

            // construct the response
            uint64_t data_resp = replicate(dice(), 0);
            responses.emplace_back(commands.back().header, data_resp);
        }
    }

    return true;
}

bool BP_me_WB_client_ctrl::sim_write() {
    // check for correct clock state
    if (d2f_resp_header->is_window() && resp_it != responses.end()) {
        unsigned __int128 header = resp_it->header;
        uint64_t data = resp_it->data;

        // check if adapter is ready
        if (d2f_resp_header->tx(header)) {
            // also send the data
            d2f_resp_data->tx(data);
            
            resp_it++;
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
