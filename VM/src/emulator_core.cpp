#include <pybind11/pybind11.h>
#include "Vcounter.h"
#include "verilated.h"

namespace py = pybind11;

class CounterSim {
public:
    Vcounter* top;
    
    CounterSim() {
        top = new Vcounter;
        top->clk = 0;
        top->rst = 1; // При старте держим Reset
        top->eval();
    }

    ~CounterSim() {
        top->final();
        delete top;
    }

    // Сброс (Reset)
    void reset_device() {
        top->rst = 1;
        top->eval();
        top->rst = 0; // Отпускаем Reset
        top->eval();
    }

    // Один полный такт (0 -> 1 -> 0)
    void step() {
        // Позитивный фронт (Rising Edge)
        top->clk = 1;
        top->eval();
        
        // Негативный фронт (Falling Edge)
        top->clk = 0;
        top->eval();
    }

    // Чтение выхода
    int get_count() {
        return top->count;
    }
};

// Биндинги для Python
PYBIND11_MODULE(logos_emu, m) {
    m.doc() = "Logos FHE Emulator Core (Verilator Backend)";

    py::class_<CounterSim>(m, "CounterSim")
        .def(py::init<>())
        .def("reset_device", &CounterSim::reset_device)
        .def("step", &CounterSim::step)
        .def("get_count", &CounterSim::get_count);
}
