#include <pybind11/pybind11.h>
#include "Vvec_alu.h"
#include "verilated.h"
#include <memory>

namespace py = pybind11;

// Stateless ALU calculator wrapper
uint64_t alu_calc(int opcode, uint64_t a, uint64_t b, uint64_t q) {
    // Instantiate the module
    auto top = std::make_unique<Vvec_alu>();
    
    // Drive inputs
    top->opcode = opcode;
    top->op_a = a;
    top->op_b = b;
    top->q = q;
    
    // Evaluate (Combinatorial logic)
    top->eval();
    
    // Read output
    return top->res_out;
}

PYBIND11_MODULE(alu_tester, m) {
    m.doc() = "Verilator Vector ALU Tester (Day 2)";
    m.def("calc", &alu_calc, "Perform ALU operation: 0=ADD, 1=SUB, 2=MULT");
}
