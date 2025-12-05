#include <pybind11/pybind11.h>
#include "Vlogos_core.h"
#include "verilated.h"
#include "svdpi.h"

// External references
void init_ram();
void cleanup_ram();
long long py_read_ram(long long addr);
extern "C" void py_write_ram(long long addr, long long val);

namespace py = pybind11;

class LogosSim {
public:
    Vlogos_core* top;
    
    LogosSim() {
        top = new Vlogos_core;
        top->clk = 0; top->rst = 0; top->eval();
        printf("[CPP] Reset...\n");
        top->rst = 1; tick();
        top->rst = 0; tick();
    }
    ~LogosSim() { top->final(); delete top; }

    void tick() { top->clk = 1; top->eval(); top->clk = 0; top->eval(); }
    void reset_state() { top->rst = 1; tick(); top->rst = 0; tick(); }
    
    void run() {
        int timeout = 2000;
        printf("[CPP] Run Loop...\n");
        while (!top->halted && timeout > 0) { tick(); timeout--; }
        if (timeout == 0) throw std::runtime_error("Logos Core Timeout");
        printf("[CPP] Finished.\n");
    }
    
    void push_command(int core_mask) {
        top->cmd_valid = 1;
        uint64_t cmd = 0x0100000000000000; 
        if (core_mask == 1) cmd |= (1ULL << 55);
        top->cmd_data = cmd;
        tick(); top->cmd_valid = 0;
    }
    
    void push_dma() {
        top->cmd_valid = 1;
        top->cmd_data = 0x0200000000000000; // CMD_DMA (0x02)
        tick(); top->cmd_valid = 0;
    }
    
    void push_halt() {
        top->cmd_valid = 1;
        top->cmd_data = 0; 
        tick(); top->cmd_valid = 0;
    }
};

PYBIND11_MODULE(logos_emu, m) {
    m.def("py_write_ram", &py_write_ram);
    m.def("py_read_ram", &py_read_ram);

    py::class_<LogosSim>(m, "LogosContext")
        .def(py::init<>())
        .def("run", &LogosSim::run)
        .def("reset_state", &LogosSim::reset_state)
        .def("push_ntt_op", [](LogosSim& self, int core_id, int slot) { self.push_command(core_id); })
        .def("push_dma", &LogosSim::push_dma)
        .def("push_halt", &LogosSim::push_halt);
}
