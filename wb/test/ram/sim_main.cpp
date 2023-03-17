#include "verilated.h"
#include "svdpi.h"
#include "verilated_vcd_c.h"
#include "Vtop.h"
#include "bsg_nonsynth_dpi_clock_gen.hpp"

#include "bp_pkg.h"
#include "bp_me_wb_master_ctrl.h"

#include <iostream>
#include <memory>

using namespace bsg_nonsynth_dpi;

void tick(Vtop *dut, VerilatedVcdC *tfp) {
    bsg_timekeeper::next();
    dut->eval();
    tfp->dump(Verilated::time());
}

uint8_t get_byte(uint64_t data, int i) {
    return (data >> (8*i)) & 0xFF;
}

bool check_packets(const std::vector<BP_pkg>& commands,
                   const std::vector<BP_pkg>& responses,
                   int& errors) {
    bool error_found = false;
    std::array<uint8_t, 4096> ram{0};
    for (int i = 0; i < commands.size(); ++i) {
        if (errors >= 3)
            break;

        int data_size = 1 << commands[i].size;
        int transfers = data_size / 8 + (data_size < 8);
        uint64_t current_addr = commands[i].addr & 0xFFF;
        uint64_t wrap_low = (current_addr / (8 * transfers)) * (8 * transfers);
        uint64_t wrap_high = wrap_low + 8 * transfers;
        if (data_size > 8)
            data_size = 8;

        for (int j = 0; j < transfers; ++j) {
            // depending on the message type, either update the
            // emulated ram or test if the response data was correct
            if (commands[i].msg_type == 0b0011) {
                // write operation
                for (int k = 0; k < data_size; k++)
                    ram[current_addr + k] = get_byte(commands[i].data[j], k);
            } else {
                // read operation
                uint64_t data_ram = 0;
                uint64_t data_pkg = 0;
                for (int k = 0; k < data_size; ++k) {
                    data_ram = data_ram << 8
                               | ram[current_addr + data_size-1 - k];
                    data_pkg = data_pkg << 8
                               | get_byte(responses[i].data[j], data_size-1 - k);
                }

                if (data_ram != data_pkg) {
                    uint8_t wb_addr = current_addr >> 3;
                    std::cout << "\nError: Read incorrect data form the RAM\n";
                    std::cout << "BP Address:\t"
                              << VL_TO_STRING(current_addr) << "\n";
                    std::cout << "WB Address:\t" << VL_TO_STRING(wb_addr) << "\n";
                    std::cout << "Data size:\t" << +data_size << " bytes\n";
                    std::cout << "Data read was " << VL_TO_STRING(data_pkg)
                              << ", but should have been "
                              << VL_TO_STRING(data_ram) << "\n";

                    ++errors;
                    error_found = true;
                }
            }

            current_addr += 8;
            if (current_addr == wrap_high)
                current_addr = wrap_low;
        }
    }

    return error_found;
}

int main(int argc, char* argv[]) {
    // initialize Verilator, the DUT and tracing
    Verilated::commandArgs(argc, argv);
    Verilated::traceEverOn(VM_TRACE_VCD);

    auto dut = std::make_unique<Vtop>();
    auto tfp = std::make_unique<VerilatedVcdC>();
    dut->trace(tfp.get(), 10);
    Verilated::mkdir("logs");
    tfp->open("logs/wave.vcd");

    // create controllers for the adapters
    int test_size = 100000;
    std::random_device r;
    unsigned long seed = r();
    BP_me_WB_master_ctrl ram_ctrl{test_size, seed};

    // simulate until all responses have been recieved
    dut->eval();
    tfp->dump(Verilated::time());
    while (!ram_ctrl.done()) {
        ram_ctrl.sim_read();
        ram_ctrl.sim_write();
        tick(dut.get(), tfp.get());

        // progress bar
        int len = 50;
        int responses = ram_ctrl.get_progress();
        int progress = len * (static_cast<double>(responses) / test_size);
        std::string bar = "[" + std::string(progress, '=')
            + ((progress == len) ? "=" : ">")
            + std::string(len-progress, ' ') + "] "
            + std::to_string(responses) + "/" + std::to_string(test_size)
            + " (" + std::to_string(100 * responses / test_size) + "%)";
        std::cout << "\r" << bar;
    }
    std::cout << "\n";
    tfp->close();
    VerilatedCov::write("logs/coverage.dat");

    // test if commands and responses were transmitted correctly
    int errors = 0;
    const std::vector<BP_pkg>& commands = ram_ctrl.get_commands();
    const std::vector<BP_pkg>& responses = ram_ctrl.get_responses();

    // check the amount of packages received
    if (responses.size() != test_size) {
        std::cout << "\nError: Master adapter did not receive " 
                  << "the correct amount of responses: "
                  << responses.size() << " instead of " << test_size << "\n";
        errors = 3;
    }

    // check if the respose data was correct by emulating a ram
    if (errors < 3) {
        std::cout << "\nChecking transmissions\n";
        if (!check_packets(commands, responses, errors))
            std::cout << "No errors found\n";
    } else {
        std::cout << "\nSkipped checking transmissions due to previous errors\n";
    }

    std::cout << "\n-- SUMMARY ---------------------\n"
              << "Total simulation time: " << Verilated::time() << " ticks\n";
    if (errors == 0)
        std::cout << "Check succeeded\n";
    else
        std::cout << "Check failed\n";

    return errors > 0;
}
