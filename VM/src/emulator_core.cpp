#include <pybind11/pybind11.h>
#include "Vlogos_core.h"
#include "verilated.h"
#include "svdpi.h"

// --- EXTERNAL LINKAGE ---
extern "C" {
    void init_ram();
    void cleanup_ram();
    void py_write_ram(long long addr, long long val);
    long long py_read_ram(long long addr);
    
    // DPI Stubs (not strictly needed if linked correctly, but safe to decl)
    void dpi_read_burst(long long, int, const svOpenArrayHandle);
    void dpi_write_burst(long long, int, const svOpenArrayHandle);
}

namespace py = pybind11;

class LogosSim {
public:
    std::unique_ptr<Vlogos_core> top;

    LogosSim() {
        // Init memory
        init_ram();
        
        top = std::make_unique<Vlogos_core>();
        top->clk = 0;
        top->rst = 0;
        top->eval();
    }

    ~LogosSim() {
        top->final();
        cleanup_ram();
    }

    void tick() {
        top->clk = 1; top->eval();
        top->clk = 0; top->eval();
    }

    void reset_state() {
        top->rst = 1; tick();
        top->rst = 0; tick();
    }

    // Debug Access
    int get_core_ops(int core_id) {
        if (core_id == 0) return top->perf_ops_0;
        if (core_id == 1) return top->perf_ops_1;
        return 0;
    }
};

PYBIND11_MODULE(logos_emu, m) {
    m.def("py_write_ram", &py_write_ram);
    m.def("py_read_ram", &py_read_ram);

    py::class_<LogosSim>(m, "LogosContext")
        .def(py::init<>())
        .def("reset_state", &LogosSim::reset_state)
        .def("get_core_ops", &LogosSim::get_core_ops);
}
