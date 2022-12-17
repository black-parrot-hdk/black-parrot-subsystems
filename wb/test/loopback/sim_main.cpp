#include "verilated.h"
#include "svdpi.h"
#include "verilated_fst_c.h"
#include "Vtop.h"
#include "bsg_nonsynth_dpi_clock_gen.hpp"

#include "bp_pkg.h"
#include "bp_me_wb_master_ctrl.h"
#include "bp_me_wb_client_ctrl.h"

#include <iostream>
#include <memory>

using namespace bsg_nonsynth_dpi;

void tick(Vtop *dut, VerilatedFstC *tfp) {
    bsg_timekeeper::next();
    dut->eval();
    tfp->dump(Verilated::time());
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
    int test_size = 1000000;
    std::random_device r;
    unsigned long int seed = r();//time(0);
    BP_me_WB_master_ctrl master_ctrl{test_size, seed};
    BP_me_WB_client_ctrl client_ctrl{test_size, seed};

    // simulate until all responses have been recieved
    dut->eval();
    tfp->dump(Verilated::time());
    int c = 0;
    while (!master_ctrl.done()) {
        if (!master_ctrl.sim_read())
            break;
        if (!client_ctrl.sim_read())
            break;

        if (!client_ctrl.sim_write())
            break;
        if (!master_ctrl.sim_write())
            break;
        tick(dut.get(), tfp.get());

        // progress bar
        int len = 50;
        int responses = master_ctrl.get_progress();
        int progress = len * (static_cast<double>(responses) / test_size);
        std::string bar = "[" + std::string(progress, '=')
            + ((progress == len) ? "=" : ">")
            + std::string(len-progress, ' ') + "] "
            + std::to_string(responses) + "/" + std::to_string(test_size)
            + " (" + std::to_string(100 * responses / test_size) + "%)";
        std::cout << "\r" << bar;

        if (c > 100)
            ;//break;
        else
            c++;
    }
    std::cout << "\n";
    tfp->close();
    VerilatedCov::write("logs/coverage.dat");

    // test if commands and responses were transmitted correctly
    int errors = 0;
    std::vector<BP_pkg> commands_in = master_ctrl.get_commands();
    std::vector<BP_pkg> commands_out = client_ctrl.get_commands();
    std::vector<BP_pkg> responses_in = client_ctrl.get_responses();
    std::vector<BP_pkg> responses_out = master_ctrl.get_responses();

    // check the amount of packages sent and received
    if (commands_out.size() != test_size) {
        std::cout << "\nError: Client adapter did not receive "
            << "the correct amount of commands: "
            << commands_out.size() << " instead of " << test_size << "\n";
        errors = 3;
    }
    if (responses_in.size() != test_size) {
        std::cout << "\nError: Client adapter did not send " 
            << "the correct amount of responses: "
            << responses_in.size() << " instead of " << test_size << "\n";
        errors = 3;
    }
    if (responses_out.size() != test_size) {
        std::cout << "\nError: Master adapter did not receive " 
            << "the correct amount of responses: "
            << responses_out.size() << " instead of " << test_size << "\n";
        errors = 3;
    }

    // check if there were errors in the transmitted commands
    for (int i = 0; errors < 3 && i < test_size; i++) {
        BP_pkg cmd_in = commands_in[i];
        BP_pkg cmd_out = commands_out[i];

        // data is only compared for write commands
        bool header_error = !(cmd_in.header == cmd_out.header);
        bool data_error = cmd_in.msg_type == 0b0011 && !(cmd_in.data == cmd_out.data);

        if (header_error || data_error) {
            std::cout << "\nError: cmd_in != cmd_out\n";
            std::cout << "Header in:  "
                << VL_TO_STRING(cmd_in.header) << "\n";
            std::cout << "Header out: "
                << VL_TO_STRING(cmd_out.header) << "\n";
            errors++;
        }

        if (data_error) {
            std::cout << "Data in:\n";
            for (uint64_t data : cmd_in.data)
                std::cout << "  " << VL_TO_STRING(data) << "\n";

            std::cout << "Data out:\n";
            for (uint64_t data : cmd_out.data)
                std::cout << "  " << VL_TO_STRING(data) << "\n";
        } else if (header_error) {
            std:: cout << "Data is only compared for write commands\n";
        }
    }

    // check if there were errors in the transmitted responses
    for (int i = 0; errors < 3 && i < test_size; i++) {
        BP_pkg resp_in = responses_in[i];
        BP_pkg resp_out = responses_out[i];

        // data is only compared for read responses
        bool header_error = !(resp_in.header == resp_out.header);
        bool data_error = resp_in.msg_type == 0b0010 && !(resp_in.data == resp_out.data);

        if (header_error || data_error) {
            std::cout << "\nError: resp_in != resp_out\n";
            std::cout << "Header in:  "
                << VL_TO_STRING(resp_in.header) << "\n";
            std::cout << "Header out: "
                << VL_TO_STRING(resp_out.header) << "\n";
            errors++;
        }

        if (data_error) {
            std::cout << "Data in:\n";
            for (uint64_t data : resp_in.data)
                std::cout << "  " << VL_TO_STRING(data) << "\n";

            std::cout << "Data out:\n";
            for (uint64_t data : resp_out.data)
                std::cout << "  " << VL_TO_STRING(data) << "\n";
        } else if (header_error) {
            std:: cout << "Data is only compared for read responses\n";
        }
    }

    std::cout << "\n-- SUMMARY ---------------------"
        << "\nTotal simulation time: " << Verilated::time() << " ticks\n";
    if (errors == 0)
        std::cout << "Check succeeded\n";
    else
        std::cout << "Check failed\n";

    return errors != 0;
}
