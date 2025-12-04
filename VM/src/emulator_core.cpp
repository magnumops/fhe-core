#include <pybind11/pybind11.h>
#include "Vburst_test.h"
#include "verilated.h"

// External functions from dpi_impl.cpp
void init_ram();
void cleanup_ram();
void py_write_ram(uint64_t addr, uint64_t val);

// External functions from fhe_impl.cpp
void py_init_fhe();
pybind11::bytes py_encrypt(int value);
int py_decrypt(pybind11::bytes cipher);
pybind11::bytes py_add(pybind11::bytes c1, pybind11::bytes c2);

namespace py = pybind11;

class BurstSim {
public:
    Vburst_test* top;
    BurstSim() {
        init_ram();
        top = new Vburst_test;
        top->clk = 0; top->eval();
    }
    ~BurstSim() {
        top->final(); delete top; cleanup_ram();
    }
    void step() { top->clk = 1; top->eval(); top->clk = 0; top->eval(); }
    void set_start_addr(uint64_t addr) { top->start_addr = addr; top->eval(); }
    uint64_t get_data_0() { return top->data_0; }
    uint64_t get_data_9() { return top->data_9; }
};

PYBIND11_MODULE(logos_emu, m) {
    m.doc() = "Logos FHE Emulator (SEAL Integrated)";

    // RAM
    m.def("py_write_ram", &py_write_ram);

    // FHE
    m.def("fhe_init", &py_init_fhe);
    m.def("fhe_encrypt", &py_encrypt);
    m.def("fhe_decrypt", &py_decrypt);
    m.def("fhe_add", &py_add);

    py::class_<BurstSim>(m, "BurstSim")
        .def(py::init<>())
        .def("step", &BurstSim::step)
        .def("set_start_addr", &BurstSim::set_start_addr)
        .def("get_data_0", &BurstSim::get_data_0)
        .def("get_data_9", &BurstSim::get_data_9);
}
