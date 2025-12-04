#include <pybind11/pybind11.h>
#include <pybind11/stl.h>
#include "Vlogos_core.h" // NEW TOP LEVEL
#include "verilated.h"
#include "dpi_impl.h"
#include "isa_spec.h"

namespace py = pybind11;

VirtualRAM* g_ram = nullptr;
CommandQueue* g_queue = nullptr;

class Emulator {
    Vlogos_core* top;
    VirtualRAM* ram;
    CommandQueue* queue;
public:
    Emulator() {
        ram = new VirtualRAM();
        queue = new CommandQueue();
        g_ram = ram;
        g_queue = queue; // Though dpi_impl uses static global, this keeps it symmetric
        
        top = new Vlogos_core;
        top->rst = 1; top->clk = 0; 
        // Default context
        top->ctx_q = 0; top->ctx_mu = 0; top->ctx_n_inv = 0;
        
        top->eval();
        top->rst = 0; top->eval();
    }
    ~Emulator() { delete top; delete ram; delete queue; }

    void write_ram(uint64_t addr, const std::vector<uint64_t>& data) { ram->write(addr, data); }
    std::vector<uint64_t> read_ram(uint64_t addr, size_t size) { return ram->read(addr, size); }

    void set_context(uint64_t q, uint64_t mu, uint64_t n_inv) {
        top->ctx_q = q;
        top->ctx_mu = mu;
        top->ctx_n_inv = n_inv;
    }

    // Push raw command
    void push_command(uint64_t cmd) {
        queue->push(cmd);
    }

    // Helper: Push NTT Command
    void push_ntt_op(uint64_t addr, int mode) {
        // [63:56] Opcode | [55:0] Addr
        uint64_t op = (mode == 1) ? OPC_INTT : OPC_NTT;
        uint64_t cmd = (op << 56) | (addr & 0x00FFFFFFFFFFFFFF);
        queue->push(cmd);
    }
    
    // Helper: Push Halt
    void push_halt() {
        uint64_t cmd = (uint64_t)OPC_HALT << 56;
        queue->push(cmd);
    }

    // Run until HALT command executed
    void run() {
        int timeout = 5000000;
        
        // Ensure we are not halted initially
        if (top->halted) {
             // If halted, maybe we need to reset or just toggle clock?
             // Since we didn't expose hard reset here, let's assume halted resets on new cmd? 
             // No, FSM S_HALTED needs Reset. 
             // Let's Pulse Reset briefly at start of Run to be safe? 
             // Ideally we shouldn't reset RAM.
             // For now, let's rely on constructor reset.
        }

        while (!top->halted && timeout > 0) {
            top->clk = 0; top->eval();
            top->clk = 1; top->eval();
            timeout--;
        }
        if (timeout == 0) throw std::runtime_error("Logos Core Timeout (Never Halted)");
    }
};

PYBIND11_MODULE(logos_emu, m) {
    py::class_<Emulator>(m, "Emulator")
        .def(py::init<>())
        .def("write_ram", &Emulator::write_ram)
        .def("read_ram", &Emulator::read_ram)
        .def("set_context", &Emulator::set_context)
        .def("push_command", &Emulator::push_command)
        .def("push_ntt_op", &Emulator::push_ntt_op)
        .def("push_halt", &Emulator::push_halt)
        .def("run", &Emulator::run);
}
