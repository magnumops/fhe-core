#include <pybind11/pybind11.h>
#include <iostream>
#include <map>
#include <verilated.h>
#include <verilated_vcd_c.h>
#include "Vlogos_core.h"
#include "svdpi.h"

// --- Реализация Виртуальной Памяти ---
// Используем map для хранения данных (адрес -> значение)
static std::map<long long, long long> global_ram;

extern "C" {
    // DPI Export: Verilog вызывает эту функцию для чтения
    long long read_ram(long long addr) {
        if (global_ram.count(addr)) return global_ram[addr];
        return 0; // Если адрес пуст, возвращаем 0
    }

    // DPI Export: Verilog вызывает эту функцию для записи
    void write_ram(long long addr, long long data) {
        global_ram[addr] = data;
    }

    // Вспомогательные функции для C++/Python
    void init_ram() {
        global_ram.clear();
    }

    void cleanup_ram() {
        global_ram.clear();
    }

    void py_write_ram(long long addr, long long val) {
        global_ram[addr] = val;
    }

    long long py_read_ram(long long addr) {
        return read_ram(addr);
    }
}

// --- Класс Симуляции ---
static Vlogos_core* top = nullptr;
static vluint64_t main_time = 0;

double sc_time_stamp() { return main_time; }

class LogosSim {
public:
    LogosSim() {
        if (!top) {
            top = new Vlogos_core;
            Verilated::traceEverOn(true);
            init_ram();
        }
    }

    ~LogosSim() {
        if (top) {
            top->final();
            delete top;
            top = nullptr;
            cleanup_ram();
        }
    }

    void reset_state() {
        top->rst = 1;
        this->tick();
        this->tick();
        top->rst = 0;
        top->cmd_valid = 0;
        top->cmd_opcode = 0;
        top->cmd_slot = 0;
        top->cmd_dma_addr = 0;
        this->tick();
    }

    void push_command(uint32_t opcode, uint32_t slot, uint64_t addr, uint32_t target) {
        top->cmd_valid = 1;
        top->cmd_opcode = opcode;
        top->cmd_slot = slot;
        top->cmd_dma_addr = addr;
        top->cmd_target = target;
        this->tick();
        top->cmd_valid = 0;
        top->cmd_opcode = 0;
    }

    void tick() {
        top->clk = 1; top->eval(); main_time++;
        top->clk = 0; top->eval(); main_time++;
    }

    uint64_t get_ticks() { return main_time; }
};

namespace py = pybind11;
PYBIND11_MODULE(logos_emu, m) {
    py::class_<LogosSim>(m, "LogosContext")
        .def(py::init<>())
        .def("reset_state", &LogosSim::reset_state)
        .def("tick", &LogosSim::tick)
        .def("push_command", &LogosSim::push_command, py::arg("opcode"), py::arg("slot"), py::arg("addr"), py::arg("target")=0)
        .def("get_ticks", &LogosSim::get_ticks);
    m.def("write_ram", [](long long addr, long long val) { py_write_ram(addr, val); });
    m.def("read_ram", [](long long addr) { return py_read_ram(addr); });
}
