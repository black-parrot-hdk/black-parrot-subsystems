#include "verilated.h"
#include "verilated_fst_c.h"
#include "Vtop.h"
#include "bp_packages.h"

#include <iostream>
#include <random>
#include <functional>

#define TEST_SIZE 100000

std::default_random_engine generator(time(0));
std::uniform_int_distribution<uint64_t> distribution;
auto dice = std::bind(distribution, generator);

VL_SIG8(, 3, 0) gen_msg_type(VL_SIG64(addr, 39, 0)) {
    int write = dice() % 2;
    if (addr >= 0x80000000)
        // ... ? e_bedrock_mem_wr : e_bedrock_mem_rd;
        return write ? 1 : 0 ;
    else
        // ... ? e_bedrock_mem_uc_wr : e_bedrock_mem_uc_rd;
        return write ? 3 : 2 ;
}

VL_SIG64(, 63, 0) replicate(VL_SIG64(data, 63, 0), VL_SIG8(size, 2, 0)) {
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

// After calling timer_tick, the sim time will stop right before the next rising clk edge.
// This way users can peek the final results of a cycle (like the SystemVerilog
// Postponed Region).
void timer_tick(Vtop *dut, VerilatedContext *contextp, VerilatedFstC *tfp) {
    dut->eval();
    tfp->dump(contextp->time());
    contextp->timeInc(1);

    dut->clk_i = 0;
    dut->eval();
    tfp->dump(contextp->time());
    contextp->timeInc(1);
}
// After users finish reading the final results of a cycle, they call timer_eval to move to
// the next time slot.
// After calling time_eval, the signals in DUT will be computed. Users can then specify the
// new input signals to the DUT. This resembles the SystemVerilog Reactive Region.
void timer_eval(Vtop *dut) {
    dut->clk_i = 1;
    dut->eval();
}


int main(int argc, char* argv[]) {
    std::unique_ptr<VerilatedContext> contextp(new VerilatedContext);
    contextp->commandArgs(argc, argv);
    std::unique_ptr<VerilatedFstC> tfp(new VerilatedFstC);
    contextp->traceEverOn(VM_TRACE_FST);
    std::unique_ptr<Vtop> dut(new Vtop(contextp.get()));

    dut->trace(tfp.get(), 10);
    Verilated::mkdir("waveforms");
    tfp->open("waveforms/wave.fst");
    contextp->time(0);
    
    timer_eval(dut.get());
    dut->reset_i = 1;
    dut->c_lce_id_i = 0;
    dut->c_did_i = 0;
    timer_tick(dut.get(), contextp.get(), tfp.get());

    timer_eval(dut.get());
    dut->reset_i = 0;
    timer_tick(dut.get(), contextp.get(), tfp.get());
    
    bool error = false;
    for (int i = 0; i < TEST_SIZE; i++) {
        // generate a command
        VL_SIG8(size, 2, 0) = dice() & 0x3;
        VL_SIG64(addr, 39, 0) = dice() & 0xFFFFFFFFF8;
        VL_SIG8(msg_type, 3, 0) = gen_msg_type(addr);
        VL_SIG64(data_cmd, 63, 0) = replicate(dice(), size);
        BP_cmd cmd_in(size, addr, msg_type, data_cmd);

        // input the command to the master adapter
        timer_eval(dut.get());
        dut->m_mem_cmd_header_i = cmd_in.header;
        dut->m_mem_cmd_data_i = cmd_in.data;
        dut->m_mem_cmd_v_i = 1;
        dut->c_mem_cmd_ready_i = 0;
        timer_tick(dut.get(), contextp.get(), tfp.get());
        timer_eval(dut.get());
        dut->m_mem_cmd_v_i = 0;

        // wait a few cycles to check backpressure
        int delay = dice() % 8;
        for (int j = 0; j < delay; j++) {
            timer_tick(dut.get(), contextp.get(), tfp.get());
            timer_eval(dut.get());
        }
        dut->c_mem_cmd_ready_i = 1;

        // wait for the command from the slave adapter
        while (!dut->c_mem_cmd_v_o) {
            timer_tick(dut.get(), contextp.get(), tfp.get());
            timer_eval(dut.get());
        }
        dut->c_mem_cmd_ready_i = 0;

        // read the cmd from the slave adapter's output
        BP_cmd cmd_out(dut->c_mem_cmd_header_o, dut->c_mem_cmd_data_o);

        // wait a few cycles
        delay = dice() % 8;
        for (int j = 0; j < delay; j++) {
            timer_tick(dut.get(), contextp.get(), tfp.get());
            timer_eval(dut.get());
        }

        // create and send the response
        VL_SIG64(data_resp, 63, 0) = replicate(dice(), size);
        BP_resp resp_in(cmd_out, data_resp);
        dut->c_mem_resp_header_i = resp_in.header;
        dut->c_mem_resp_data_i = resp_in.data;
        dut->c_mem_resp_v_i = 1;
        timer_tick(dut.get(), contextp.get(), tfp.get());

        // wait for the response from the master adapter
        timer_eval(dut.get());
        dut->c_mem_resp_v_i = 0;
        while (!dut->m_mem_resp_v_o) {
            timer_tick(dut.get(), contextp.get(), tfp.get());
            timer_eval(dut.get());
        }

        // read the response
        BP_resp resp_out(dut->m_mem_resp_header_o, dut->m_mem_resp_data_o);

        // set the yumi signal after a tick
        dut->m_mem_resp_yumi_i = 1;
        timer_tick(dut.get(), contextp.get(), tfp.get());
        timer_eval(dut.get());
        dut->m_mem_resp_yumi_i = 0;

        // wait a few more cycles
        delay = dice() % 8 + 1;
        for (int j = 0; j < delay; j++) {
            timer_tick(dut.get(), contextp.get(), tfp.get());
            timer_eval(dut.get());
        }
        timer_tick(dut.get(), contextp.get(), tfp.get());

        // pre-compute values used for output
        int len = 50;
        int done = len * ((double) (i+1) / TEST_SIZE);
        std::string progress = "[" + std::string(done, '=')
            + ((done == len) ? "=" : ">")
            + std::string(len-done, ' ') + "] "
            + std::to_string((i+1)) + "/" + std::to_string(TEST_SIZE)
            + " (" + std::to_string(100 * (i+1) / TEST_SIZE) + "%)";

        // check for errors
        std::cout << "\r";
        if (!(cmd_in == cmd_out)) {
            std::cout << "Error: cmd_in != cmd_out\n";
            std::cout << "Addr:       " << VL_TO_STRING(addr) << "\n";
            std::cout << "Header in:  " << VL_TO_STRING_W(3, cmd_in.header) << "\n";
            std::cout << "Header out: " << VL_TO_STRING_W(3, cmd_out.header) << "\n";
            std::cout << "Data in:    " << VL_TO_STRING(cmd_in.data) << "\n";
            std::cout << "Data out:   " << VL_TO_STRING(cmd_out.data) << "\n\n";
            error = true;
        }
        if (!(resp_in == resp_out)) {
            std::cout << "Error: resp_in != resp_out\n";
            std::cout << "Addr:       " << VL_TO_STRING(addr) << "\n";
            std::cout << "Header in:  " << VL_TO_STRING_W(3, resp_in.header) << "\n";
            std::cout << "Header out: " << VL_TO_STRING_W(3, resp_out.header) << "\n";
            std::cout << "Data in:    " << VL_TO_STRING(resp_in.data) << "\n";
            std::cout << "Data out:   " << VL_TO_STRING(resp_out.data) << "\n\n";
            error = true;
        }

        // progress bar
        std::cout << progress;
    }

    std::cout << "\n\n-- SUMMARY ---------------------"
        << "\nTotal simulation time: " << contextp->time() << " cycles\n";
    tfp->close();
    if (error)
        std::cout << "Check failed\n";
    else
        std::cout << "Check succeeded\n";

    return 0;
}
