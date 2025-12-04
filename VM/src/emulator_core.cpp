#include <pybind11/pybind11.h>
#include <pybind11/stl.h>   // <--- FIX: Required for std::vector conversion
#include "Vntt_engine.h"
#include "verilated.h"
#include "dpi_impl.h"

namespace py = pybind11;

// Global pointer for Singleton Pattern (DPI access)
VirtualRAM* g_ram = nullptr;

class Emulator {
    Vntt_engine* top;
    VirtualRAM* ram;
public:
    Emulator() {
        // Initialize RAM
        ram = new VirtualRAM();
        g_ram = ram; // Set global for DPI

        // Initialize Verilator Model
        // Legacy API for compatibility with older Verilator in Ubuntu 22.04
        top = new Vntt_engine;
        top->rst = 1; top->clk = 0; top->start = 0;
        top->eval();
        top->rst = 0; top->eval();
    }

    ~Emulator() {
        delete top;
        delete ram;
        g_ram = nullptr;
    }

    // --- MEMORY ACCESS ---
    void write_ram(uint64_t addr, const std::vector<uint64_t>& data) {
        ram->write(addr, data);
    }

    std::vector<uint64_t> read_ram(uint64_t addr, size_t size) {
        return ram->read(addr, size);
    }

    // --- CORE EXECUTION ---
    void run_ntt(uint64_t dma_addr) {
        top->dma_addr = dma_addr;
        top->start = 1;
        
        // Pulse Start
        top->clk = 0; top->eval();
        top->clk = 1; top->eval();
        top->start = 0;
        
        // Wait for Done
        int timeout = 10000;
        while (!top->done && timeout > 0) {
            top->clk = 0; top->eval();
            top->clk = 1; top->eval();
            timeout--;
        }
        
        if (timeout == 0) {
            throw std::runtime_error("NTT Hardware Timeout!");
        }
    }
};

PYBIND11_MODULE(logos_emu, m) {
    py::class_<Emulator>(m, "Emulator")
        .def(py::init<>())
        .def("write_ram", &Emulator::write_ram)
        .def("read_ram", &Emulator::read_ram)
        .def("run_ntt", &Emulator::run_ntt);
}
