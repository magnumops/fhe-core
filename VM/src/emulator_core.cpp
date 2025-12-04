#include <pybind11/pybind11.h>
#include "Vburst_test.h" // Используем новый модуль
#include "verilated.h"

void init_ram();
void cleanup_ram();
void py_write_ram(uint64_t addr, uint64_t val);

namespace py = pybind11;

class BurstSim {
public:
    Vburst_test* top;
    
    BurstSim() {
        init_ram();
        top = new Vburst_test;
        top->clk = 0;
        top->eval();
    }

    ~BurstSim() {
        top->final();
        delete top;
        cleanup_ram();
    }

    void step() {
        top->clk = 1; top->eval();
        top->clk = 0; top->eval();
    }

    void set_start_addr(uint64_t addr) {
        top->start_addr = addr;
        top->eval();
    }

    uint64_t get_data_0() { return top->data_0; }
    uint64_t get_data_9() { return top->data_9; }
};

PYBIND11_MODULE(logos_emu, m) {
    m.doc() = "Logos FHE Emulator with Burst Mode";
    m.def("py_write_ram", &py_write_ram);

    py::class_<BurstSim>(m, "BurstSim")
        .def(py::init<>())
        .def("step", &BurstSim::step)
        .def("set_start_addr", &BurstSim::set_start_addr)
        .def("get_data_0", &BurstSim::get_data_0)
        .def("get_data_9", &BurstSim::get_data_9);
}
