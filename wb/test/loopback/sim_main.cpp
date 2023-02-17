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
#include <numeric>

using namespace bsg_nonsynth_dpi;

void tick(Vtop *dut, VerilatedFstC *tfp) {
    bsg_timekeeper::next();
    dut->eval();
    tfp->dump(Verilated::time());
}

long count_bytes(std::vector<BP_pkg> packages) {
    long bytes = 0;
    for (const BP_pkg& package : packages)
        bytes += 1 << package.size;
    return bytes;
}

void print_header(const BP_pkg& pkg) {
    std::cout << VL_TO_STRING(pkg.header)
              << "\n  msg_type: " << VL_TO_STRING(pkg.msg_type)
              << "\n  subop:    " << VL_TO_STRING(pkg.subop)
              << "\n  addr:     " << VL_TO_STRING(pkg.addr)
              << "\n  size:     " << VL_TO_STRING(pkg.size)
              << "\n  payload:  " << VL_TO_STRING(pkg.payload)
              << "\n";
}

bool check_packets(const std::vector<BP_pkg>& master_pkgs,
                   const std::vector<BP_pkg>& client_pkgs,
                   int& errors,
                   bool is_command) {
    // commands with a size >64b are split into multiple commands by the client
    // adapter, so we have to be a bit fancy here
    bool error_found = false;
    auto client_pkg_it = client_pkgs.begin();
    for (const BP_pkg& master_pkg : master_pkgs) {
        if (errors >= 3)
            break;

        int bits = (1 << master_pkg.size) * 8;
        int transfers = bits / 64 + (bits < 64);
        uint64_t wrap_low = (master_pkg.addr / (8 * transfers)) * (8 * transfers);
        uint64_t wrap_high = wrap_low + 8 * transfers;
        uint64_t current_addr = master_pkg.addr;
        for (int i = 0; i < transfers; ++i) {
            const BP_pkg& client_pkg = *client_pkg_it;

            // check the various header fields for differences
            std::vector<std::string> diff;
            if (master_pkg.msg_type != client_pkg.msg_type)
                diff.push_back("msg_type");
            if (master_pkg.subop != client_pkg.subop)
                diff.push_back("subop");
            if (current_addr != client_pkg.addr)
                diff.push_back("addr");
            // don't check the size, as it is allowed to differ
            // if (master_pkg.size != ...)
            if (master_pkg.payload != client_pkg.payload)
                diff.push_back("payload");
            // data only needs to be checked for write commands or
            // read responses
            bool comp_data = (is_command == (master_pkg.msg_type == 0b0011));
            if (comp_data && master_pkg.data[i] != client_pkg.data.front())
                diff.push_back("data");
            
            // print an error message if a difference was found
            if (!diff.empty()) {
                std::cout << "\nError: Different " << std::accumulate(
                    ++diff.begin(), diff.end(), *diff.begin(), [](auto& a, auto& s) {
                        return a + ", " + s;
                }) << "\n";

                std::cout << "Master header:  ";
                print_header(master_pkg);
                std::cout << "Client header: ";
                print_header(client_pkg);

                if (std::find(diff.begin(), diff.end(), "data") != diff.end()) {
                    std::cout << "Master data: "
                              << VL_TO_STRING(master_pkg.data[i]) << "\n";
                    std::cout << "Client data: "
                              << VL_TO_STRING(client_pkg.data.front()) << "\n";
                }

                ++errors;
                error_found = true;
            }

            current_addr += 8;
            if (current_addr == wrap_high)
                current_addr = wrap_low;
            ++client_pkg_it;
        }
    }

    return error_found;
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
    std::random_device r;
    unsigned long seed = r();
    BP_me_WB_master_ctrl master_ctrl{test_size, seed};
    BP_me_WB_client_ctrl client_ctrl{test_size, seed};

    // simulate until all responses have been recieved
    dut->eval();
    tfp->dump(Verilated::time());
    while (!master_ctrl.done()) {
        master_ctrl.sim_read();
        client_ctrl.sim_read();
        client_ctrl.sim_write();
        master_ctrl.sim_write();
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
    }
    std::cout << "\n";
    tfp->close();
    VerilatedCov::write("logs/coverage.dat");

    // test if commands and responses were transmitted correctly
    int errors = 0;
    const std::vector<BP_pkg>& commands_in = master_ctrl.get_commands();
    const std::vector<BP_pkg>& commands_out = client_ctrl.get_commands();
    const std::vector<BP_pkg>& responses_in = client_ctrl.get_responses();
    const std::vector<BP_pkg>& responses_out = master_ctrl.get_responses();

    // check the amount of transmitted bytes
    long bytes_master_in = count_bytes(commands_in);
    long bytes_client_out = count_bytes(commands_out);
    long bytes_client_in = count_bytes(responses_in);
    long bytes_master_out = count_bytes(responses_out);

    if (bytes_client_out != bytes_master_in) {
        std::cout << "\nError: Client adapter did not receive "
                  << "the correct amount of bytes: "
                  << bytes_client_out << " instead of "
                  << bytes_master_in << "\n";
        errors = 3;
    }
    if (bytes_master_out != bytes_client_in) {
        std::cout << "\nError: Master adapter did not receive " 
                  << "the correct amount of bytes: "
                  << bytes_master_out << " instead of "
                  << bytes_client_in << "\n";
        errors = 3;
    }

    // check if there were errors in the transmitted commands and responses
    if (errors < 3) {
        std::cout << "\nChecking commands\n";
        if (!check_packets(commands_in, commands_out, errors, true))
            std::cout << "No errors found\n";
    } else {
        std::cout << "\nSkipped checking commands due to previous errors\n";
    }
    if (errors < 3) {
        std::cout << "\nChecking responses\n";
        if (!check_packets(responses_out, responses_in, errors, false))
            std::cout << "No errors found\n";
    } else {
        std::cout << "\nSkipped checking responses due to previous errors\n";
    }

    std::cout << "\n-- SUMMARY ---------------------\n"
              << "Total simulation time: " << Verilated::time() << " ticks\n";
    if (errors == 0)
        std::cout << "Check succeeded\n";
    else
        std::cout << "Check failed\n";

    return errors > 0;
}
