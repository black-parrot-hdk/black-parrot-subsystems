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

long int count_bytes(std::vector<BP_pkg> packages) {
    long int bytes = 0;
    for (const BP_pkg& package : packages)
        bytes += 1 << package.size;
    return bytes;
}

/*void print_header(const BP_pkg& pkg) {
    std::cout << VL_TO_STRING(pkg.header) << std::hex
        << "  msg_type: " << pkg.msg_type
        << "  subop:    " << pkg.subop
        << "  addr:     " << pkg.addr
        << "  size:     " << pkg.size
        << "  payload:  " << pkg.payload << "\n";
}*/

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
    int test_size = 1;
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

    // check the amount of transmitted bytes
    long int bytes_master_in = count_bytes(commands_in);
    long int bytes_client_out = count_bytes(commands_out);
    long int bytes_client_in = count_bytes(responses_in);
    long int bytes_master_out = count_bytes(responses_out);

    if (bytes_client_out != bytes_master_in) {
        std::cout << "\nError: Client adapter did not receive "
            << "the correct amount of bytes: "
            << bytes_client_out << " instead of " << bytes_master_in << "\n";
        errors = 3;
    }
    if (bytes_master_out != bytes_client_in) {
        std::cout << "\nError: Master adapter did not receive " 
            << "the correct amount of bytes: "
            << bytes_master_out << " instead of " << bytes_client_in << "\n";
        errors = 3;
    }

    // check if there were errors in the transmitted commands
    // commands with a size >64b are split into multiple commands by the client
    // adapter, so we have to be a bit fancy here
    auto cmd_out_it = commands_out.begin();
    for (const BP_pkg& cmd_in : commands_in) {
        if (errors >= 3)
            break;

        bool error = false;
        if (cmd_in.header != cmd_out_it->header) {
            std::cout << "\nError: cmd_in != cmd_out\n";
            std::cout << "Header in:  ";
            //print_header(cmd_in);
            std::cout << "Header out: ";
            //print_header(*cmd_out_it);
            error = true;
        }

        // data only needs to be checked for write commands
        if (cmd_in.msg_type == 0b0011) {
            for (uint64_t data_in : cmd_in.data) {

                // every output command contains exactly one transfer
                uint64_t data_out = cmd_out_it->data[0];
                cmd_out_it++;

                if (data_out != data_in) {
                    if (!error) {
                        std::cout << "\nError: cmd_in != cmd_out\n";
                        std::cout << "Header in:  ";
                        //print_header(cmd_in);
                        std::cout << "Header out: ";
                        //print_header(*cmd_out_it);
                    }

                    std::cout << "Data in:    "
                        << VL_TO_STRING(data_in) << "\n";
                    std::cout << "Data out:   "
                        << VL_TO_STRING(data_out) << "\n";

                    error = true;
                }
            }
        } else {
            cmd_out_it++;
        }

        if (error)
            errors++;
    }

    // perform the same checks for the responses
    auto resp_in_it = responses_in.begin();
    for (const BP_pkg& resp_out : responses_out) {
        if (errors >= 3)
            break;

        bool error = false;
        if (resp_in_it->header != resp_out.header) {
            std::cout << "\nError: resp_in != resp_out\n";
            std::cout << "Header in:  ";
            //print_header(*resp_in_it);
            std::cout << "Header out: ";
            //print_header(resp_out);
            error = true;
        }

        // data only needs to be checked for read responses
        if (resp_out.msg_type == 0b0010) {
            for (uint64_t data_out : resp_out.data) {

                // every output command contains exactly one transfer
                uint64_t data_in = resp_in_it->data[0];
                resp_in_it++;

                if (data_out != data_in) {
                    if (!error) {
                        std::cout << "\nError: resp_in != resp_out\n";
                        std::cout << "Header in:  ";
                        //print_header(*resp_in_it);
                        std::cout << "Header out: ";
                        //print_header(resp_out);
                    }

                    std::cout << "Data in:    "
                        << VL_TO_STRING(data_in) << "\n";
                    std::cout << "Data out:   "
                        << VL_TO_STRING(data_out) << "\n";

                    error = true;
                }
            }
        } else {
            resp_in_it++;
        }

        if (error)
            errors++;
    }

    // check if there were errors in the transmitted responses
    /*for (int i = 0; i < tms_client_in && errors < 3; i++) {
        BP_pkg resp_in = responses_in[i];
        BP_pkg resp_out = responses_out[i];

        // data is only compared for read responses
        bool header_error = resp_in.header != resp_out.header;
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
    }*/

    std::cout << "\n-- SUMMARY ---------------------"
        << "\nTotal simulation time: " << Verilated::time() << " ticks\n";
    if (errors == 0)
        std::cout << "Check succeeded\n";
    else
        std::cout << "Check failed\n";

    return 0;
}
