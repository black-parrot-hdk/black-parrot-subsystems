#include "verilated.h"
#include "verilated_fst_c.h"
#include "Vtop.h"
#include "bsg_nonsynth_dpi_clock_gen.hpp"

#include "bp_me_wb_master_ctrl.h"
#include "bp_me_wb_client_ctrl.h"
#include "bp_packages.h"

#include <iostream>
#include <functional>

// After calling timer_tick, the sim time will stop right before the next
// rising clk edge. This way users can peek the final results of a cycle
// (like the SystemVerilog Postponed Region).
void timer_tick(Vtop *dut, VerilatedFstC *tfp) {
    dut->eval();
    tfp->dump(Verilated::time());

    bsg_nonsynth_dpi::bsg_timekeeper::next();
    dut->eval();
    tfp->dump(Verilated::time());
}
// After users finish reading the final results of a cycle, they call
// timer_eval to move to the next time slot.
// After calling time_eval, the signals in DUT will be computed. Users can
// then specify the new input signals to the DUT. This resembles the
// SystemVerilog Reactive Region.
void timer_eval(Vtop *dut) {
    bsg_nonsynth_dpi::bsg_timekeeper::next();
    dut->eval();
}

int main(int argc, char* argv[]) {
    // initialize Verilator, the DUT and tracing
    Verilated::commandArgs(argc, argv);
    Verilated::traceEverOn(VM_TRACE_FST);

    auto dut = std::make_unique<Vtop>();
    auto tfp = std::make_unique<VerilatedFstC>();
    dut->trace(tfp.get(), 10);
    Verilated::mkdir("waveforms");
    tfp->open("waveforms/wave.fst");

    // create controllers for the adapters
    int test_size = 10000;
    unsigned long int seed = time(0);
    BP_me_WB_master_ctrl master_ctrl{
        test_size,
        seed,
        dut->reset_o,
        dut->m_mem_cmd_header_i,
        dut->m_mem_cmd_data_i,
        dut->m_mem_cmd_v_i,
        dut->m_mem_cmd_ready_o,
        dut->m_mem_resp_header_o,
        dut->m_mem_resp_data_o,
        dut->m_mem_resp_v_o,
        dut->m_mem_resp_yumi_i
    };
    BP_me_WB_client_ctrl client_ctrl{
        test_size,
        seed,
        dut->reset_o,
        dut->c_mem_cmd_header_o,
        dut->c_mem_cmd_data_o,
        dut->c_mem_cmd_v_o,
        dut->c_mem_cmd_ready_i,
        dut->c_mem_resp_header_i,
        dut->c_mem_resp_data_i,
        dut->c_mem_resp_v_i,
        dut->c_mem_resp_ready_o
    };

    // simulate until all responses have been recieved
    dut->c_did_i = 0;
    dut->c_lce_id_i = 0;
    timer_tick(dut.get(), tfp.get());
    while (!master_ctrl.done()) {
        if (!client_ctrl.sim_write())
            break;
        if (!master_ctrl.sim_write())
            break;
        timer_eval(dut.get());

        if (!master_ctrl.sim_read())
            break;
        if (!client_ctrl.sim_read())
            break;
        timer_tick(dut.get(), tfp.get());

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

    // test if commands and responses were transmitted correctly
    int error = 0;
    std::vector<BP_cmd> commands_in = master_ctrl.get_commands();
    std::vector<BP_cmd> commands_out = client_ctrl.get_commands();
    std::vector<BP_resp> responses_in = client_ctrl.get_responses();
    std::vector<BP_resp> responses_out = master_ctrl.get_responses();

    if (commands_out.size() != test_size) {
        std::cout << "\nError: Client adapter did not receive "
            << "the correct amount of commands: "
            << commands_out.size() << " instead of " << test_size << "\n";
        error = 3;
    }
    if (responses_in.size() != test_size) {
        std::cout << "\nError: Client adapter did not send " 
            << "the correct amount of responses: "
            << responses_in.size() << " instead of " << test_size << "\n";
        error = 3;
    }
    if (responses_out.size() != test_size) {
        std::cout << "\nError: Master adapter did not receive " 
            << "the correct amount of responses: "
            << responses_out.size() << " instead of " << test_size << "\n";
        error = 3;
    }

    for (int i = 0; error < 3 && i < test_size; i++) {
        if (!(commands_in[i] == commands_out[i])) {
            std::cout << "\nError: cmd_in != cmd_out\n";
            std::cout << "Header in:  "
                << VL_TO_STRING_W(3, commands_in[i].header) << "\n";
            std::cout << "Header out: "
                << VL_TO_STRING_W(3, commands_out[i].header) << "\n";
            std::cout << "Data in:    "
                << VL_TO_STRING(commands_in[i].data) << "\n";
            std::cout << "Data out:   "
                << VL_TO_STRING(commands_out[i].data) << "\n";
            error++;
        }
    }

    for (int i = 0; error < 3 && i < test_size; i++) {
        if (!(responses_in[i] == responses_out[i])) {
            std::cout << "\nError: resp_in != resp_out\n";
            std::cout << "Header in:  "
                << VL_TO_STRING_W(3, responses_in[i].header) << "\n";
            std::cout << "Header out: "
                << VL_TO_STRING_W(3, responses_out[i].header) << "\n";
            std::cout << "Data in:    "
                << VL_TO_STRING(responses_in[i].data) << "\n";
            std::cout << "Data out:   "
                << VL_TO_STRING(responses_out[i].data) << "\n";
            error++;
        }
    }

    std::cout << "\n-- SUMMARY ---------------------"
        << "\nTotal simulation time: " << Verilated::time() << " cycles\n";
    if (error)
        std::cout << "Check failed\n";
    else
        std::cout << "Check succeeded\n";

    return 0;
}
