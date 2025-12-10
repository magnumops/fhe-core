#include <pybind11/pybind11.h>
#include <pybind11/stl.h> // Для возврата pair/tuple
#include <verilated.h>
#include "Vntt_arith_unit.h"

namespace py = pybind11;

class NTTSimulator {
    Vntt_arith_unit* top;
public:
    NTTSimulator() {
        top = new Vntt_arith_unit;
        top->rst = 1;
        top->clk = 0;
        top->eval();
        top->rst = 0;
        top->eval();
    }
    ~NTTSimulator() { delete top; }

    // Возвращаем кортеж (res1, res2)
    std::pair<uint64_t, uint64_t> step(int opcode, uint64_t a, uint64_t b, uint64_t w, uint64_t q) {
        top->opcode = opcode;
        top->op_a = a;
        top->op_b = b;
        top->op_w = w; // New input
        top->op_q = q;
        
        top->clk = 0; top->eval();
        top->clk = 1; top->eval();
        
        return std::make_pair(top->res_out_1, top->res_out_2);
    }
};

PYBIND11_MODULE(ntt_tester, m) {
    py::class_<NTTSimulator>(m, "NTTSimulator")
        .def(py::init<>())
        .def("step", &NTTSimulator::step);
}
