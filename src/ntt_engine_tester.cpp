#include <pybind11/pybind11.h>
#include <pybind11/stl.h>
#include <verilated.h>
#include "Vntt_engine.h"

namespace py = pybind11;

class NTTEngineSim {
    Vntt_engine* top;
public:
    NTTEngineSim() {
        top = new Vntt_engine;
        top->rst = 1; top->clk = 0; top->start = 0;
        top->eval();
        top->rst = 0; top->eval();
    }
    ~NTTEngineSim() { delete top; }

    // Загрузка данных в память эмулятора
    void load_memory(const std::vector<uint64_t>& data) {
        top->start = 0;
        top->rw_mode = 1; // Write Mode
        
        for (size_t i = 0; i < data.size(); ++i) {
            top->rw_addr = i;
            top->rw_data_in = data[i];
            
            // Clock tick to latch data
            top->clk = 0; top->eval();
            top->clk = 1; top->eval();
        }
        top->rw_mode = 0; // Disable write
    }

    // Чтение памяти
    std::vector<uint64_t> read_memory(size_t size) {
        std::vector<uint64_t> res;
        top->start = 0;
        top->rw_mode = 0; // Read Mode
        
        for (size_t i = 0; i < size; ++i) {
            top->rw_addr = i;
            // Clock tick to update rw_data_out
            top->clk = 0; top->eval();
            top->clk = 1; top->eval();
            res.push_back(top->rw_data_out);
        }
        return res;
    }

    // Запуск NTT
    void run() {
        top->start = 1;
        // Pulse start
        top->clk = 0; top->eval();
        top->clk = 1; top->eval();
        top->start = 0;
        
        // Wait for done with timeout
        for (int i = 0; i < 100; ++i) {
            top->clk = 0; top->eval();
            top->clk = 1; top->eval();
            if (top->done) break;
        }
    }
};

PYBIND11_MODULE(ntt_engine_tester, m) {
    py::class_<NTTEngineSim>(m, "NTTEngineSim")
        .def(py::init<>())
        .def("load_memory", &NTTEngineSim::load_memory)
        .def("read_memory", &NTTEngineSim::read_memory)
        .def("run", &NTTEngineSim::run);
}
