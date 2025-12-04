#include <pybind11/pybind11.h>
#include <pybind11/stl.h>
#include <verilated.h>
#include "Vntt_control.h"

namespace py = pybind11;

class AGUSimulator {
    Vntt_control* top;
public:
    AGUSimulator() {
        // Legacy API: No VerilatedContext explicitly managed here
        // Just create the model instance.
        top = new Vntt_control;
        
        top->rst = 1;
        top->clk = 0;
        top->start = 0;
        top->eval();
        
        top->rst = 0;
        top->eval();
    }
    ~AGUSimulator() { delete top; }

    void start() {
        top->start = 1;
        top->eval();
        top->clk = 1; top->eval(); // Posedge
        top->clk = 0; top->eval();
        top->start = 0; 
    }

    std::tuple<int, int, int, int, int> tick() {
        // Clock High
        top->clk = 1; 
        top->eval();
        
        // Read outputs at posedge
        int v_valid = top->valid;
        int v_u = top->addr_u;
        int v_v = top->addr_v;
        int v_w = top->addr_w;
        int v_done = top->done;

        // Clock Low
        top->clk = 0; 
        top->eval();
        
        return std::make_tuple(v_valid, v_u, v_v, v_w, v_done);
    }
};

PYBIND11_MODULE(ntt_agu_tester, m) {
    py::class_<AGUSimulator>(m, "AGUSimulator")
        .def(py::init<>())
        .def("start", &AGUSimulator::start)
        .def("tick", &AGUSimulator::tick);
}
