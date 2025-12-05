#include <pybind11/pybind11.h>
#include "Vlogos_core.h"
#include "verilated.h"
#include "svdpi.h"

// External declarations
void init_ram();
void cleanup_ram();
long long py_read_ram(long long addr);
extern "C" void py_write_ram(long long addr, long long val);

namespace py = pybind11;

class LogosSim {
public:
    Vlogos_core* top;
    
    LogosSim() {
        top = new Vlogos_core;
        top->clk = 0; top->rst = 0; top->eval();
        top->rst = 1; tick();
        top->rst = 0; tick();
    }
    ~LogosSim() { top->final(); delete top; }

    void tick() { top->clk = 1; top->eval(); top->clk = 0; top->eval(); }
    void reset_state() { top->rst = 1; tick(); top->rst = 0; tick(); }
    
    void run() {
        int timeout = 5000;
        while (!top->halted && timeout > 0) { tick(); timeout--; }
        if (timeout == 0) throw std::runtime_error("Logos Core Timeout");
    }
    
    // FIX: Handshake Push
    // Ждем, пока железо скажет "Ready", прежде чем убирать команду
    void push_command(int core_mask) {
        // 1. Выставляем команду
        top->cmd_valid = 1;
        uint64_t cmd = 0x0100000000000000; 
        if (core_mask == 1) cmd |= (1ULL << 55);
        top->cmd_data = cmd;
        top->eval(); // Обновляем комбинаторную логику (cmd_ready)

        // 2. Ждем принятия (Backpressure handling)
        int wait_limit = 100;
        while (top->cmd_ready == 0 && wait_limit > 0) {
            tick(); // Ждем такт, пока ядро освободится
            wait_limit--;
        }
        
        if (wait_limit == 0) {
             printf("[CPP] WARNING: Command push timed out (Backpressure stuck)\n");
        }

        // 3. Команда принята (Clock edge happened in tick)
        tick(); 
        
        // 4. Убираем валидность
        top->cmd_valid = 0;
        top->eval();
    }
    
    void push_dma() {
        top->cmd_valid = 1;
        top->cmd_data = 0x0200000000000000;
        top->eval();
        // DMA usually ready, but good practice to wait
        tick(); 
        top->cmd_valid = 0;
    }
    
    void push_halt() {
        top->cmd_valid = 1;
        top->cmd_data = 0; 
        // Halt is always accepted
        tick(); 
        top->cmd_valid = 0;
    }

    int get_core_ops(int core_id) {
        if (core_id == 0) return top->perf_ops_0;
        if (core_id == 1) return top->perf_ops_1;
        return -1;
    }
};

PYBIND11_MODULE(logos_emu, m) {
    m.def("py_write_ram", &py_write_ram);
    m.def("py_read_ram", &py_read_ram);

    py::class_<LogosSim>(m, "LogosContext")
        .def(py::init<>())
        .def("run", &LogosSim::run)
        .def("reset_state", &LogosSim::reset_state)
        .def("push_ntt_op", [](LogosSim& self, int core_id, int slot) { self.push_command(core_id); })
        .def("push_dma", &LogosSim::push_dma)
        .def("push_halt", &LogosSim::push_halt)
        .def("get_core_ops", &LogosSim::get_core_ops);
}
