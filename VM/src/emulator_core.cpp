#include <pybind11/pybind11.h>
#include "Vmem_test.h" // Теперь используем mem_test вместо counter
#include "verilated.h"

// Объявления внешних функций из dpi_impl.cpp
void init_ram();
void cleanup_ram();
void py_write_ram(uint64_t addr, uint64_t val);

namespace py = pybind11;

// Симулятор для теста памяти
class MemorySim {
public:
    Vmem_test* top;
    
    MemorySim() {
        init_ram(); // Создаем память при старте
        top = new Vmem_test;
        top->clk = 0;
        top->eval();
    }

    ~MemorySim() {
        top->final();
        delete top;
        cleanup_ram(); // Удаляем память
    }

    void step() {
        top->clk = 1; top->eval();
        top->clk = 0; top->eval();
    }

    void set_addr(uint64_t addr) {
        top->addr = addr;
        top->eval();
    }

    uint64_t get_data() {
        return top->data;
    }
};

PYBIND11_MODULE(logos_emu, m) {
    m.doc() = "Logos FHE Emulator with DPI Memory";

    // Экспортируем функции управления памятью
    m.def("py_write_ram", &py_write_ram, "Write to RAM from Python");

    py::class_<MemorySim>(m, "MemorySim")
        .def(py::init<>())
        .def("step", &MemorySim::step)
        .def("set_addr", &MemorySim::set_addr)
        .def("get_data", &MemorySim::get_data);
}
