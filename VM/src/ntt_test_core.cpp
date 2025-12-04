#include <pybind11/pybind11.h>
#include <verilated.h>
#include "Vntt_arith_unit.h"

namespace py = pybind11;

// Класс-обертка для симулятора
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

    uint64_t step(int opcode, uint64_t a, uint64_t b, uint64_t q) {
        // Установка входов
        top->opcode = opcode;
        top->op_a = a;
        top->op_b = b;
        top->op_q = q;
        
        // Такт часов
        top->clk = 0; top->eval();
        top->clk = 1; top->eval();
        
        // Возврат результата
        return top->res_out;
    }
};

PYBIND11_MODULE(ntt_tester, m) {
    py::class_<NTTSimulator>(m, "NTTSimulator")
        .def(py::init<>())
        .def("step", &NTTSimulator::step);
}
