#include <pybind11/pybind11.h>
#include <pybind11/stl.h>
#include <iostream>
#include "Vlogos_core.h"
#include "verilated.h"
#include "dpi_impl.h"
#include "isa_spec.h"

namespace py = pybind11;

double sc_time_stamp() { return 0; }

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
        g_queue = queue;
        top = new Vlogos_core;
        top->rst = 1; top->clk = 0; 
        top->ctx_q = 0; top->ctx_mu = 0; top->ctx_n_inv = 0;
        top->eval();
        top->rst = 0; top->eval();
    }
    ~Emulator() { delete top; delete ram; delete queue; }

    void reset_state() {
        top->rst = 1; top->eval();
        top->clk = 0; top->eval();
        top->clk = 1; top->eval();
        top->rst = 0; top->eval();
        queue->clear();
    }

    void write_ram(uint64_t addr, const std::vector<uint64_t>& data) { ram->write(addr, data); }
    std::vector<uint64_t> read_ram(uint64_t addr, size_t size) { return ram->read(addr, size); }

    void set_context(uint64_t q, uint64_t mu, uint64_t n_inv) {
        top->ctx_q = q; top->ctx_mu = mu; top->ctx_n_inv = n_inv;
    }

    void push_command(uint64_t cmd) { queue->push(cmd); }
    void push_halt() { queue->push((uint64_t)OPC_HALT << 56); }

    void push_load_op(int slot, uint64_t host_addr) {
        uint64_t cmd = ((uint64_t)OPC_LOAD << 56) | ((uint64_t)(slot & 0xF) << 52) | (host_addr & 0xFFFFFFFFFFFF);
        queue->push(cmd);
    }
    
    void push_load_w_op(uint64_t host_addr) {
        uint64_t cmd = ((uint64_t)OPC_LOAD_W << 56) | (host_addr & 0xFFFFFFFFFFFF);
        queue->push(cmd);
    }

    void push_store_op(int slot, uint64_t host_addr) {
        uint64_t cmd = ((uint64_t)OPC_STORE << 56) | ((uint64_t)(slot & 0xF) << 52) | (host_addr & 0xFFFFFFFFFFFF);
        queue->push(cmd);
    }

    void push_ntt_op(int slot, int mode) {
        uint64_t op = (mode == 1) ? OPC_INTT : OPC_NTT;
        uint64_t cmd = (op << 56) | ((uint64_t)(slot & 0xF) << 52);
        queue->push(cmd);
    }

    // NEW: ALU Operation (Target OP Source)
    void push_alu_op(int op_code, int target_slot, int source_slot) {
        // [63:56] Opcode
        // [55:52] Target Slot
        // [47:46] Source Slot (Encoded in top 2 bits of DMA Addr field)
        uint64_t cmd = ((uint64_t)op_code << 56) | 
                       ((uint64_t)(target_slot & 0xF) << 52) | 
                       ((uint64_t)(source_slot & 0x3) << 46);
        queue->push(cmd);
    }

    void run() {
        int timeout = 1000000;
        int cycle = 0;
        while (!top->halted && timeout > 0) {
            top->clk = 0; top->eval();
            top->clk = 1; top->eval();
            timeout--; cycle++;
        }
        if (timeout == 0) throw std::runtime_error("Logos Core Timeout");
    }
};

PYBIND11_MODULE(logos_emu, m) {
    py::class_<Emulator>(m, "Emulator")
        .def(py::init<>())
        .def("reset_state", &Emulator::reset_state)
        .def("write_ram", &Emulator::write_ram)
        .def("read_ram", &Emulator::read_ram)
        .def("set_context", &Emulator::set_context)
        .def("push_command", &Emulator::push_command)
        .def("push_halt", &Emulator::push_halt)
        .def("push_load_op", &Emulator::push_load_op)
        .def("push_load_w_op", &Emulator::push_load_w_op)
        .def("push_store_op", &Emulator::push_store_op)
        .def("push_ntt_op", &Emulator::push_ntt_op)
        .def("push_alu_op", &Emulator::push_alu_op) // Exposed
        .def("run", &Emulator::run);
}
