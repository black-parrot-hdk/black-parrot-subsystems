#include "Vbsg_axil_demux.h"
#include "verilated.h"
#include <cstdio>
#include <cstdint>
#include <iostream>
#include <verilated_fst_c.h>
#include <random>
#include <queue>
#include <functional>
#include <cassert>

#define TEST_SIZE 16384

using namespace std;

// Set your seed here:
#define SEED 9877
mt19937 random_generator(SEED);
uniform_int_distribution<uint32_t> distribution;
auto dice = bind(distribution, random_generator); 


// After calling timer_tick, the sim time will stop right before the next rising clk edge.
// This way users can peek the final results of a cycle (like the SystemVerilog
// Postponed Region).
void timer_tick(Vbsg_axil_demux *dut, VerilatedContext *contextp, VerilatedFstC *tfp)
{
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
void timer_eval(Vbsg_axil_demux *dut)
{
    dut->clk_i = 1;
    dut->eval();
}


class axil_master {
    private:
        int master_id;
        queue<uint32_t> waddr;
        size_t waddr_max = 8;
        bool waddr_next = true;
        queue<uint32_t> wdata;
        size_t wdata_max = 8;
        bool wdata_next = true;
        queue<uint32_t> raddr;
        size_t raddr_max = 8;
        bool raddr_next = true;

        VL_IN  (&axil_awaddr,31,0);
        VL_IN8 (&axil_awprot,2,0);
        VL_IN8 (&axil_awvalid,0,0);
        VL_OUT8(&axil_awready,0,0);
        VL_IN  (&axil_wdata,31,0);
        VL_IN8 (&axil_wstrb,3,0);
        VL_IN8 (&axil_wvalid,0,0);
        VL_OUT8(&axil_wready,0,0);
        VL_OUT8(&axil_bresp,1,0);
        VL_OUT8(&axil_bvalid,0,0);
        VL_IN8 (&axil_bready,0,0);
        VL_IN  (&axil_araddr,31,0);
        VL_IN8 (&axil_arprot,2,0);
        VL_IN8 (&axil_arvalid,0,0);
        VL_OUT8(&axil_arready,0,0);
        VL_OUT (&axil_rdata,31,0);
        VL_OUT8(&axil_rresp,1,0);
        VL_OUT8(&axil_rvalid,0,0);
        VL_IN8 (&axil_rready,0,0);

    public:
        struct request {
            bool is_write;
            union {
                struct {
                    uint32_t waddr;
                    uint32_t wdata;
                } w;
                struct {
                    uint32_t raddr;
                } r;
            } u;
        };
        struct response {
            bool is_write;
            uint32_t rdata;
        };
        struct request *request_array;
        size_t request_array_idx;
        struct response *response_array;
        size_t response_array_idx;
        bool done;
        axil_master(
            VL_IN  (&axil_awaddr,31,0),VL_IN8 (&axil_awprot,2,0),
            VL_IN8 (&axil_awvalid,0,0),VL_OUT8(&axil_awready,0,0),
            VL_IN  (&axil_wdata,31,0), VL_IN8 (&axil_wstrb,3,0),
            VL_IN8 (&axil_wvalid,0,0), VL_OUT8(&axil_wready,0,0),
            VL_OUT8(&axil_bresp,1,0),  VL_OUT8(&axil_bvalid,0,0),
            VL_IN8 (&axil_bready,0,0), VL_IN  (&axil_araddr,31,0),
            VL_IN8 (&axil_arprot,2,0), VL_IN8 (&axil_arvalid,0,0),
            VL_OUT8(&axil_arready,0,0),VL_OUT (&axil_rdata,31,0),
            VL_OUT8(&axil_rresp,1,0),  VL_OUT8(&axil_rvalid,0,0),
            VL_IN8 (&axil_rready,0,0), int master_id):
        axil_awaddr (axil_awaddr), axil_awprot (axil_awprot),
        axil_awvalid(axil_awvalid), axil_awready(axil_awready),
        axil_wdata  (axil_wdata), axil_wstrb  (axil_wstrb),
        axil_wvalid (axil_wvalid), axil_wready (axil_wready),
        axil_bresp  (axil_bresp), axil_bvalid (axil_bvalid),
        axil_bready (axil_bready), axil_araddr (axil_araddr),
        axil_arprot (axil_arprot), axil_arvalid(axil_arvalid),
        axil_arready(axil_arready), axil_rdata  (axil_rdata),
        axil_rresp  (axil_rresp), axil_rvalid (axil_rvalid),
        axil_rready (axil_rready) {
            this->axil_awaddr = 0;
            this->axil_awprot = 0;
            this->axil_awvalid = 0;
            this->axil_wdata = 0;
            this->axil_wstrb = 0;
            this->axil_wvalid = 0;
            this->axil_bready = 0;
            this->axil_araddr = 0;
            this->axil_arprot = 0;
            this->axil_arvalid = 0;
            this->axil_rready = 0;
            this->master_id = master_id;
            done = false;
            request_array  = new struct request[TEST_SIZE];
            request_array_idx  = 0;
            response_array = new struct response[TEST_SIZE];
            response_array_idx = 0;
            for(size_t i = 0;i < TEST_SIZE;i++) {
                bool is_write = dice() & 1U;
                request_array[i].is_write = is_write;
                if(is_write) {
                    request_array[i].u.w.waddr = dice();
                    request_array[i].u.w.wdata = dice();
                }
                else {
                    request_array[i].u.r.raddr = dice();
                    
                }
            }
        }
        ~axil_master()
        {
            delete [] request_array;
            delete [] response_array;
        }
        int sim(bool post_read)
        {
            if(done == true)
                return 0;
            if(post_read == false) {
                if(request_array_idx < TEST_SIZE) {
                    bool do_write = request_array[request_array_idx].is_write;
                    // add a new AXIL operation if possible
                    if(do_write) {
                        if(waddr.size() < waddr_max && wdata.size() < wdata_max) {
                            waddr.push(request_array[request_array_idx].u.w.waddr);
                            wdata.push(request_array[request_array_idx].u.w.wdata);
                            request_array_idx++;
                        }
                    }
                    else {
                        if(raddr.size() < raddr_max) {
                            raddr.push(request_array[request_array_idx].u.r.raddr);
                            request_array_idx++;

                        }
                    }
                }
                // generate signals
                if(waddr_next == true) {
                    axil_awvalid = 0;
                    waddr_next = false;
                }
                if(wdata_next == true) {
                    axil_wvalid = 0;
                    wdata_next = false;
                }
                if(raddr_next == true) {
                    axil_arvalid = 0;
                    raddr_next = false;
                }

                if(axil_awvalid == 0 && waddr.size() != 0) {
                    if(dice() & 1U) {
                        axil_awvalid = 1;
                        axil_awaddr = waddr.front();
                        axil_awprot = 0;
                    }
                }
                if(axil_wvalid == 0 && wdata.size() != 0) {
                    if(dice() & 1U) {
                        axil_wdata = wdata.front();
                        axil_wstrb = 15U;
                        axil_wvalid = 1;
                    }
                }
                if(axil_arvalid == 0 && raddr.size() != 0) {
                    if(dice() & 1U) {
                        axil_araddr = raddr.front();
                        axil_arprot = 0;
                        axil_arvalid = 1;
                    }
                }
                axil_bready = (dice() & 1U);
                axil_rready = (dice() & 1U);
            }
            else {
                if(axil_awvalid == 1 && axil_awready == 1) {
                    if(waddr.size() == 0)
                        return -1;
                    // Master sends waddr
                    waddr.pop();
                    waddr_next = true;
                }
                if(axil_wvalid == 1 && axil_wready == 1) {
                    if(wdata.size() == 0)
                        return -1;
                    // Master sends wdata
                    wdata.pop();
                    wdata_next = true;
                }
                if(axil_arvalid == 1 && axil_arready == 1) {
                    if(raddr.size() == 0)
                        return -1;
                    // Master sends raddr
                    raddr.pop();
                    raddr_next = true;
                }
                if(axil_bvalid == 1 && axil_bready == 1) {
                    // Master receives write response
                    response_array[response_array_idx].is_write = 1;
                    response_array_idx++;
                    if(response_array_idx == TEST_SIZE)
                        done = true;
                }
                if(axil_rvalid == 1 && axil_rready == 1) {
                    // Master receives read response
                    response_array[response_array_idx].is_write = 0;
                    response_array[response_array_idx].rdata = axil_rdata;
                    response_array_idx++;
                    if(response_array_idx == TEST_SIZE)
                        done = true;
                }
            }
            return 0;
        }
};
class axil_client {
    private:
        int client_id;
        queue<uint32_t> waddr;
        size_t waddr_max = 8;
        queue<uint32_t> wdata;
        size_t wdata_max = 8;
        bool write_next = true;
        queue<uint32_t> raddr;
        size_t raddr_max = 8;
        bool read_next = true;

        VL_OUT (&axil_awaddr,31,0);
        VL_OUT8(&axil_awprot,2,0);
        VL_OUT8(&axil_awvalid,0,0);
        VL_IN8 (&axil_awready,0,0);
        VL_OUT (&axil_wdata,31,0);
        VL_OUT8(&axil_wstrb,3,0);
        VL_OUT8(&axil_wvalid,0,0);
        VL_IN8 (&axil_wready,0,0);
        VL_IN8 (&axil_bresp,1,0);
        VL_IN8 (&axil_bvalid,0,0);
        VL_OUT8(&axil_bready,0,0);
        VL_OUT (&axil_araddr,31,0);
        VL_OUT8(&axil_arprot,2,0);
        VL_OUT8(&axil_arvalid,0,0);
        VL_IN8 (&axil_arready,0,0);
        VL_IN  (&axil_rdata,31,0);
        VL_IN8 (&axil_rresp,1,0);
        VL_IN8 (&axil_rvalid,0,0);
        VL_OUT8(&axil_rready,0,0);
    public:
        struct request_response {
            bool is_write;
            union {
                struct {
                    uint32_t waddr;
                    uint32_t wdata;
                } w;
                struct {
                    uint32_t raddr;
                    uint32_t rdata;
                } r;
            } u;
        };
        struct request_response *array;
        size_t array_idx;

        axil_client(
            VL_OUT (&axil_awaddr,31,0), VL_OUT8(&axil_awprot,2,0),
            VL_OUT8(&axil_awvalid,0,0), VL_IN8 (&axil_awready,0,0),
            VL_OUT (&axil_wdata,31,0),  VL_OUT8(&axil_wstrb,3,0),
            VL_OUT8(&axil_wvalid,0,0),  VL_IN8 (&axil_wready,0,0),
            VL_IN8 (&axil_bresp,1,0),   VL_IN8 (&axil_bvalid,0,0),
            VL_OUT8(&axil_bready,0,0),  VL_OUT (&axil_araddr,31,0),
            VL_OUT8(&axil_arprot,2,0),  VL_OUT8(&axil_arvalid,0,0),
            VL_IN8 (&axil_arready,0,0), VL_IN  (&axil_rdata,31,0),
            VL_IN8 (&axil_rresp,1,0),   VL_IN8 (&axil_rvalid,0,0),
            VL_OUT8(&axil_rready,0,0), int client_id):
                axil_awaddr (axil_awaddr), axil_awprot (axil_awprot),
                axil_awvalid(axil_awvalid), axil_awready(axil_awready),
                axil_wdata  (axil_wdata), axil_wstrb  (axil_wstrb),
                axil_wvalid (axil_wvalid), axil_wready (axil_wready),
                axil_bresp  (axil_bresp), axil_bvalid (axil_bvalid),
                axil_bready (axil_bready), axil_araddr (axil_araddr),
                axil_arprot (axil_arprot), axil_arvalid(axil_arvalid),
                axil_arready(axil_arready), axil_rdata  (axil_rdata),
                axil_rresp  (axil_rresp), axil_rvalid (axil_rvalid),
                axil_rready (axil_rready) {
                    this->axil_awready = 0;
                    this->axil_wready = 0;
                    this->axil_bresp = 0;
                    this->axil_bvalid = 0;
                    this->axil_arready = 0;
                    this->axil_rdata = 0;
                    this->axil_rresp = 0;
                    this->axil_rvalid = 0;
                    this->client_id = client_id;
                    array  = new struct request_response[2 * TEST_SIZE]; // two masters
                    array_idx  = 0;
               }
        ~axil_client()
        {
            delete [] array;
        }
        int sim(bool post_read)
        {
            if(post_read == false) {
                if(write_next == true) {
                    axil_bvalid = 0;
                    write_next = false;
                }
                if(read_next == true) {
                    axil_rvalid = 0;
                    read_next = false;
                }
                if(axil_bvalid == 0 && (waddr.size() > 0 && wdata.size() > 0)) {
                    if(dice() & 1U) {
                        axil_bvalid = 1;
                        assert(array_idx < 2 * TEST_SIZE);
                        array[array_idx].is_write = 1;
                        array[array_idx].u.w.waddr = waddr.front();
                        array[array_idx].u.w.wdata = wdata.front();
                        array_idx++;
                    }
                }
                if(axil_rvalid == 0 && raddr.size() > 0) {
                    if(dice() & 1U) {
                        assert(array_idx < 2 * TEST_SIZE);
                        axil_rvalid = 1;
                        axil_rdata = dice();
                        array[array_idx].is_write = 0;
                        array[array_idx].u.r.raddr = raddr.front();
                        array[array_idx].u.r.rdata = axil_rdata;
                        array_idx++;
                    }
                }

                axil_awready = ((dice() & 1U) && (waddr.size() < waddr_max));
                axil_wready = ((dice() & 1U) && (wdata.size() < wdata_max));
                axil_arready = ((dice() & 1U) && (raddr.size() < raddr_max));
            }
            else {
                if(axil_awvalid == 1 && axil_awready == 1) {
                    // Client receives waddr
                    waddr.push(axil_awaddr);
                }
                if(axil_wvalid == 1 && axil_wready == 1) {
                    // Client receives wdata
                    wdata.push(axil_wdata);
                }
                if(axil_arvalid == 1 && axil_arready == 1) {
                    // Client receives raddr
                    raddr.push(axil_araddr);
                }
                if(axil_bvalid == 1 && axil_bready == 1) {
                    // Client sends write response
                    if(waddr.size() == 0 || wdata.size() == 0)
                        return -1;
                    waddr.pop();
                    wdata.pop();
                    write_next = true;
                }
                if(axil_rvalid == 1 && axil_rready == 1) {
                    // Client sends read response
                    if(raddr.size() == 0)
                        return -1;
                    raddr.pop();
                    read_next = true;
                }
            }
            return 0;
        }
};

void print_result(axil_master *m00, axil_client *s00, axil_client *s01)
{
    printf("m00 request:\n");
    for(size_t i = 0;i < TEST_SIZE;i++) {
        if(m00->request_array[i].is_write) {
            printf("\twaddr: %x", m00->request_array[i].u.w.waddr);
            printf("\twdata: %x\n", m00->request_array[i].u.w.wdata);
        }
        else {
            printf("\traddr: %x\n", m00->request_array[i].u.r.raddr);
        }
    }
    printf("m00 response:\n");
    for(size_t i = 0;i < TEST_SIZE;i++) {
        if(m00->response_array[i].is_write) {
            printf("\twrite response\n");
        }
        else {
            printf("\tread response: %x\n", m00->response_array[i].rdata);
        }
    }

    printf("s00 req/res:\n");
    for(size_t i = 0;i < s00->array_idx;i++) {
        if(s00->array[i].is_write) {
            printf("\twaddr: %x", s00->array[i].u.w.waddr);
            printf("\twdata: %x\n", s00->array[i].u.w.wdata);
        }
        else {
            printf("\traddr: %x", s00->array[i].u.r.raddr);
            printf("\trdata: %x\n", s00->array[i].u.r.rdata);
        }
    }

    printf("s01 req/res:\n");
    for(size_t i = 0;i < s01->array_idx;i++) {
        if(s01->array[i].is_write) {
            printf("\twaddr: %x", s01->array[i].u.w.waddr);
            printf("\twdata: %x\n", s01->array[i].u.w.wdata);
        }
        else {
            printf("\traddr: %x", s01->array[i].u.r.raddr);
            printf("\trdata: %x\n", s01->array[i].u.r.rdata);
        }
    }
}

int check(axil_master *m, axil_client *s0, axil_client *s1)
{
    size_t s_req_idx = 0;
    uint32_t waddr, wdata, raddr, rdata;
    size_t s0_idx = 0, s1_idx = 0;
    assert(m->request_array_idx == TEST_SIZE);
    assert(m->response_array_idx == TEST_SIZE);
    // check if write/read request # == write/read response #
    {
        size_t req_wcnt = 0, res_wcnt = 0, req_rcnt = 0, res_rcnt = 0;
        for(size_t i = 0;i < m->request_array_idx;i++) {
            if(m->request_array[i].is_write)
                req_wcnt++;
            else
                req_rcnt++;
            if(m->response_array[i].is_write)
                res_wcnt++;
            else
                res_rcnt++;
        }
        if((req_wcnt != res_wcnt) || (req_rcnt != res_rcnt))
            return -1;
    }
    // check clients' write req/res
    for(size_t m_req_idx = 0;m_req_idx < m->request_array_idx;m_req_idx++) {
        if(m->request_array[m_req_idx].is_write == true) {
            waddr = m->request_array[m_req_idx].u.w.waddr;
            wdata = m->request_array[m_req_idx].u.w.wdata;
            size_t *s_idx = (waddr < 0x80000000U) ? &s0_idx : &s1_idx;
            axil_client **s = (waddr < 0x80000000U) ? &s0 : &s1;
            for(;*s_idx < (*s)->array_idx;(*s_idx)++) {
                if((*s)->array[*s_idx].is_write) {
                    if((*s)->array[*s_idx].u.w.waddr == waddr &&
                            (*s)->array[*s_idx].u.w.wdata == wdata) {
                        break;
                    }
                }
            }
            if(*s_idx == (*s)->array_idx) {
                return -1;// no match
            }
        }
    }
    s0_idx = 0;
    s1_idx = 0;
    size_t m_res_idx = 0;
    // check clients' read req/res and master's read response
    for(size_t m_req_idx = 0;m_req_idx < m->request_array_idx;m_req_idx++) {
        if(m->request_array[m_req_idx].is_write == false) {
            raddr = m->request_array[m_req_idx].u.r.raddr;
            size_t *s_idx = (raddr < 0x80000000U) ? &s0_idx : &s1_idx;
            axil_client **s = (raddr < 0x80000000U) ? &s0 : &s1;
            for(;*s_idx < (*s)->array_idx;(*s_idx)++) {
                if((*s)->array[*s_idx].is_write == false) {
                    if((*s)->array[*s_idx].u.r.raddr == raddr) {
                        rdata = (*s)->array[*s_idx].u.r.rdata;
                        for(;m_res_idx < m->response_array_idx;m_res_idx++) {
                            if(m->response_array[m_res_idx].is_write == false &&
                                (m->response_array[m_res_idx].rdata == rdata)) {
                                break;
                            }
                        }
                        if(m_res_idx == m->response_array_idx) {
                            return -1; // no match
                        }
                        break;
                    }
                }
            }
            if(*s_idx == (*s)->array_idx) {
                return -1;// no match
            }
        }
    }
    return 0;
}



int main(int argc, char **argv, char **env)
{
    unique_ptr<VerilatedContext> contextp(new VerilatedContext);
	contextp->commandArgs(argc, argv);
    unique_ptr<VerilatedFstC> tfp(new VerilatedFstC);
    contextp->traceEverOn(VM_TRACE_FST);
    unique_ptr<Vbsg_axil_demux> dut(new Vbsg_axil_demux(contextp.get()));
    dut->trace(tfp.get(), 10);
    tfp->open("dump.fst");

    unique_ptr<axil_master> m00(new class axil_master(
        dut->s00_axil_awaddr,
        dut->s00_axil_awprot,
        dut->s00_axil_awvalid,
        dut->s00_axil_awready,

        dut->s00_axil_wdata,
        dut->s00_axil_wstrb,
        dut->s00_axil_wvalid,
        dut->s00_axil_wready,

        dut->s00_axil_bresp,
        dut->s00_axil_bvalid,
        dut->s00_axil_bready,

        dut->s00_axil_araddr,
        dut->s00_axil_arprot,
        dut->s00_axil_arvalid,
        dut->s00_axil_arready,

        dut->s00_axil_rdata,
        dut->s00_axil_rresp,
        dut->s00_axil_rvalid,
        dut->s00_axil_rready,
        0
    ));

   unique_ptr<axil_client> s00(new class axil_client (
        dut->m00_axil_awaddr,
        dut->m00_axil_awprot,
        dut->m00_axil_awvalid,
        dut->m00_axil_awready,

        dut->m00_axil_wdata,
        dut->m00_axil_wstrb,
        dut->m00_axil_wvalid,
        dut->m00_axil_wready,

        dut->m00_axil_bresp,
        dut->m00_axil_bvalid,
        dut->m00_axil_bready,

        dut->m00_axil_araddr,
        dut->m00_axil_arprot,
        dut->m00_axil_arvalid,
        dut->m00_axil_arready,

        dut->m00_axil_rdata,
        dut->m00_axil_rresp,
        dut->m00_axil_rvalid,
        dut->m00_axil_rready,
        0
        ));

    unique_ptr<axil_client> s01(new class axil_client (
        dut->m01_axil_awaddr,
        dut->m01_axil_awprot,
        dut->m01_axil_awvalid,
        dut->m01_axil_awready,

        dut->m01_axil_wdata,
        dut->m01_axil_wstrb,
        dut->m01_axil_wvalid,
        dut->m01_axil_wready,

        dut->m01_axil_bresp,
        dut->m01_axil_bvalid,
        dut->m01_axil_bready,

        dut->m01_axil_araddr,
        dut->m01_axil_arprot,
        dut->m01_axil_arvalid,
        dut->m01_axil_arready,

        dut->m01_axil_rdata,
        dut->m01_axil_rresp,
        dut->m01_axil_rvalid,
        dut->m01_axil_rready,
        0
        ));

	contextp->time(0);
    dut->clk_i = 1;
    dut->eval();

	dut->reset_i = 1;
	timer_tick(dut.get(), contextp.get(), tfp.get());
	timer_eval(dut.get());
    // Specify the inputs to DUT during [timer_eval, timer_tick]

	dut->reset_i = 0;
    while(!m00->done) {
        if(m00->sim(false))
            break;
        if(s00->sim(false))
            break;
        if(s01->sim(false))
            break;
    	timer_tick(dut.get(), contextp.get(), tfp.get());
        // Read end outputs from DUT during [timer_tick, timer_eval]
        if(m00->sim(true))
            break;
        if(s00->sim(true))
            break;
        if(s01->sim(true))
            break;
        timer_eval(dut.get());
    }

	printf("Total simulation time: %lu\n", contextp->time());
    tfp->close();
    // check
//    print_result(m00.get(), s00.get(), s01.get());
    if(check(m00.get(), s00.get(), s01.get()) == 0) {
        printf("Check succeeded\n");
    }
    else {
        printf("Check failed\n");
    }
	return 0;
}
