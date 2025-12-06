#include <pybind11/pybind11.h>
#include "Vlogos_core.h"
#include "verilated.h"
#include "svdpi.h"

// Используем dpi_ версии
extern "C" void dpi_write_ram(long long addr, long long val);
extern "C" long long dpi_read_ram(long long addr);

namespace py = pybind11;

class LogosSim {
public:
    Vlogos_core* top;

    LogosSim() {
        top = new Vlogos_core;
        top->clk = 0; top->rst = 0; top->eval();
        top->rst = 1; tick();
        top->rst = 0; tick();
    }
    ~LogosSim() { top->final(); delete top; }

    void tick() { top->clk = 1; top->eval(); top->clk = 0; top->eval(); }
    void step() { tick(); }
    void reset_state() { top->rst = 1; tick(); top->rst = 0; tick(); }
    void run_cycles(int n) { for(int i=0; i<n; i++) tick(); }

    void push_command(uint64_t cmd_val) {
        top->cmd_valid = 1;
        top->cmd_data = cmd_val;
        top->eval();
        int timeout = 100;
        while (top->cmd_ready == 0 && timeout > 0) { tick(); timeout--; }
        tick(); 
        top->cmd_valid = 0;
        top->eval();
    }
    
    int get_core_ops(int core_id) {
        if (core_id == 0) return top->perf_ops_0;
        if (core_id == 1) return top->perf_ops_1;
        return 0;
    }
};

PYBIND11_MODULE(logos_emu, m) {
    m.def("write_ram", &dpi_write_ram);
    m.def("read_ram", &dpi_read_ram);

    py::class_<LogosSim>(m, "LogosContext")
        .def(py::init<>())
        .def("reset", &LogosSim::reset_state)
        .def("step", &LogosSim::step)
        .def("run_cycles", &LogosSim::run_cycles)
        .def("push_command", &LogosSim::push_command)
        .def("get_core_ops", &LogosSim::get_core_ops);
}
