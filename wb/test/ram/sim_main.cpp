#include "verilated.h"
#include "svdpi.h"
#include "verilated_fst_c.h"
#include "Vtop.h"
#include "bsg_nonsynth_dpi_clock_gen.hpp"

#include "bp_pkg.h"
#include "bp_me_wb_master_ctrl.h"

#include <iostream>
#include <memory>

using namespace bsg_nonsynth_dpi;

void tick(Vtop *dut, VerilatedFstC *tfp) {
    bsg_timekeeper::next();
    dut->eval();
    tfp->dump(Verilated::time());
}

uint8_t get_byte(uint64_t data, int i) {
    return (data >> (8*i)) & 0xFF;
}

int main(int argc, char* argv[]) {
    // initialize Verilator, the DUT and tracing
    Verilated::commandArgs(argc, argv);
    Verilated::traceEverOn(VM_TRACE_FST);

    auto dut = std::make_unique<Vtop>();
    auto tfp = std::make_unique<VerilatedFstC>();
    dut->trace(tfp.get(), 10);
    Verilated::mkdir("logs");
    tfp->open("logs/wave.fst");

    // create controllers for the adapters
    int test_size = 100000;
    unsigned long int seed = time(0);
    BP_me_WB_master_ctrl ram_ctrl{test_size, seed};

    // simulate until all responses have been recieved
    dut->eval();
    tfp->dump(Verilated::time());
    while (!ram_ctrl.done()) {
        if (!ram_ctrl.sim_read())
            break;
        if (!ram_ctrl.sim_write())
            break;
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
    std::vector<BP_pkg> commands = ram_ctrl.get_commands();
    std::vector<BP_pkg> responses = ram_ctrl.get_responses();

    // check the amount of packages received
    if (responses.size() != test_size) {
        std::cout << "\nError: Master adapter did not receive " 
            << "the correct amount of responses: "
            << responses.size() << " instead of " << test_size << "\n";
        errors = 3;
    }

    // check if the respose data was correct by emulating a ram
    std::array<uint8_t, 256> ram{0};
    for (int i = 0; i < test_size && errors < 3; i++) {
        // depending on the message type, either update the
        // emulated ram or test if the response data was correct
        uint8_t addr = commands[i].addr & 0xFF;
        uint8_t data_size = 1 << commands[i].size;
        if (commands[i].msg_type == 2) {
            // read operation
            uint64_t data_ram = 0;
            uint64_t data_pkg = 0;
            for (int j = 0; j < data_size; j++) {
                data_ram = (data_ram << 8) | ram[addr + j];
                data_pkg = (data_pkg << 8) | get_byte(responses[i].data, j);
            }
            
            if (data_ram != data_pkg) {
                uint8_t wb_addr = addr >> 3;
                std::cout << "\nError: Read incorrect data form the RAM\n";
                std::cout << "BP Address:\t"
                    << VL_TO_STRING(responses[i].addr) << "\n";
                std::cout << "WB Address:\t" << VL_TO_STRING(wb_addr) << "\n";
                std::cout << "Data size:\t" << +data_size << "\n";
                std::cout << "Data read was " << VL_TO_STRING(data_pkg)
                    << ", but should have been "
                    << VL_TO_STRING(data_ram) << "\n";

                errors++;
            }
        } else {
            // write operation
            for (int j = 0; j < data_size; j++)
                ram[addr + j] = get_byte(commands[i].data, j);
        }
    }

    std::cout << "\n-- SUMMARY ---------------------"
        << "\nTotal simulation time: " << Verilated::time() << " ticks\n";
    if (errors == 0)
        std::cout << "Check succeeded\n";
    else
        std::cout << "Check failed\n";

    return 0;
}
