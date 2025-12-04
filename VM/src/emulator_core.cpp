#include <pybind11/pybind11.h>
#include "Vcopy_engine.h"
#include "verilated.h"

void init_ram();
void cleanup_ram();
void py_write_ram(uint64_t addr, uint64_t val);
uint64_t py_read_ram(uint64_t addr);

void py_init_fhe();
pybind11::bytes py_encrypt(int value);
int py_decrypt(pybind11::bytes cipher);
pybind11::bytes py_add(pybind11::bytes c1, pybind11::bytes c2);

namespace py = pybind11;

class CopySim {
public:
    Vcopy_engine* top;
    CopySim() {
        init_ram();
        top = new Vcopy_engine;
        top->clk = 0; top->start = 0; top->eval();
    }
    ~CopySim() { top->final(); delete top; cleanup_ram(); }
    
    void step() { top->clk = 1; top->eval(); top->clk = 0; top->eval(); }
    
    void start_copy(uint64_t src, uint64_t dst) {
        top->src_addr = src;
        top->dst_addr = dst;
        top->start = 1;
        step();
        top->start = 0;
        step();
    }
    
    bool is_done() { return top->done; }
};

PYBIND11_MODULE(logos_emu, m) {
    m.doc() = "Logos FHE Emulator Final MVP";
    m.def("py_write_ram", &py_write_ram);
    m.def("py_read_ram", &py_read_ram);

    m.def("fhe_init", &py_init_fhe);
    m.def("fhe_encrypt", &py_encrypt);
    m.def("fhe_decrypt", &py_decrypt);

    py::class_<CopySim>(m, "CopySim")
        .def(py::init<>())
        .def("step", &CopySim::step)
        .def("start_copy", &CopySim::start_copy)
        // ИСПРАВЛЕНИЕ: Теперь валидный C++ комментарий
        .def("is_done", &CopySim::is_done);
}
