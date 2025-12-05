#include <pybind11/pybind11.h>
#include <pybind11/stl.h>
#include <iostream>
#include <memory>
#include "Vlogos_core.h"
#include "verilated.h"
#include "verilated_vcd_c.h"
#include "dpi_impl.h"
#include "isa_spec.h"

namespace py = pybind11;

vluint64_t main_time = 0;
double sc_time_stamp() { return main_time; }

VirtualRAM* g_ram = nullptr;
CommandQueue* g_queue = nullptr;

class Emulator {
    Vlogos_core* top;
    VirtualRAM* ram;
    CommandQueue* queue;
    VerilatedVcdC* tfp;
    bool trace_enabled;
    int current_core_id; // 0 or 1

public:
    Emulator() {
        Verilated::traceEverOn(true);
        ram = new VirtualRAM();
        queue = new CommandQueue();
        g_ram = ram;
        g_queue = queue;
        top = new Vlogos_core;
        tfp = nullptr;
        trace_enabled = false;
        current_core_id = 0; // Default Core 0

        top->rst = 1; top->clk = 0;
        top->ctx_q = 0; top->ctx_mu = 0; top->ctx_n_inv = 0;
        eval_step();
        top->rst = 0; eval_step();
    }

    ~Emulator() {
        if (tfp) { tfp->close(); delete tfp; }
        delete top; delete ram; delete queue;
    }

    void eval_step() {
        top->eval();
        if (trace_enabled) tfp->dump(main_time);
        main_time++;
    }

    void start_trace(const std::string& filename) {
        if (trace_enabled) return;
        std::cout << "[INFO] Starting VCD Trace -> " << filename << std::endl;
        tfp = new VerilatedVcdC;
        top->trace(tfp, 99);
        tfp->open(filename.c_str());
        trace_enabled = true;
    }

    void stop_trace() {
        if (!trace_enabled) return;
        tfp->close(); delete tfp; tfp = nullptr; trace_enabled = false;
    }

    void reset_state() {
        top->rst = 1; eval_step();
        top->clk = 0; eval_step();
        top->clk = 1; eval_step();
        top->rst = 0; eval_step();
        queue->clear();
    }

    void write_ram(uint64_t addr, const std::vector<uint64_t>& data) { ram->write(addr, data); }
    std::vector<uint64_t> read_ram(uint64_t addr, size_t size) { return ram->read(addr, size); }
    void set_context(uint64_t q, uint64_t mu, uint64_t n_inv) { top->ctx_q = q; top->ctx_mu = mu; top->ctx_n_inv = n_inv; }

    // --- Core Selection ---
    void set_target_core(int core_id) {
        if (core_id < 0 || core_id > 1) {
            std::cerr << "[WARN] Invalid Core ID: " << core_id << ". Using 0." << std::endl;
            current_core_id = 0;
        } else {
            current_core_id = core_id;
        }
    }

    // Helper to embed Core ID into Bit 48
    uint64_t embed_core(uint64_t cmd) {
        return cmd | ((uint64_t)(current_core_id & 1) << 48);
    }

    void push_command(uint64_t cmd) { queue->push(embed_core(cmd)); }
    void push_halt() { queue->push(embed_core((uint64_t)OPC_HALT << 56)); }
    
    void push_load_op(int slot, uint64_t host_addr) { 
        queue->push(embed_core(((uint64_t)OPC_LOAD << 56) | ((uint64_t)(slot & 0xF) << 52) | (host_addr & 0xFFFFFFFFFFFF))); 
    }
    
    void push_load_w_op(uint64_t host_addr) { 
        queue->push(embed_core(((uint64_t)OPC_LOAD_W << 56) | (host_addr & 0xFFFFFFFFFFFF))); 
    }
    
    void push_store_op(int slot, uint64_t host_addr) { 
        queue->push(embed_core(((uint64_t)OPC_STORE << 56) | ((uint64_t)(slot & 0xF) << 52) | (host_addr & 0xFFFFFFFFFFFF))); 
    }
    
    void push_ntt_op(int slot, int mode) { 
        uint64_t op = (mode == 1) ? OPC_INTT : OPC_NTT;
        queue->push(embed_core(((uint64_t)op << 56) | ((uint64_t)(slot & 0xF) << 52))); 
    }
    
    void push_alu_op(int op_code, int target_slot, int source_slot) {
        queue->push(embed_core(((uint64_t)op_code << 56) | ((uint64_t)(target_slot & 0xF) << 52) | ((uint64_t)(source_slot & 0x3) << 46)));
    }

    void push_read_perf_op(uint64_t host_addr) {
        queue->push(embed_core(((uint64_t)OPC_READ_PERF << 56) | (host_addr & 0xFFFFFFFFFFFF)));
    }

    void run() {
        int timeout = 1000000;
        while (!top->halted && timeout > 0) {
            top->clk = 0; eval_step();
            top->clk = 1; eval_step();
            timeout--;
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
        .def("set_target_core", &Emulator::set_target_core) // EXPORTED
        .def("push_command", &Emulator::push_command)
        .def("push_halt", &Emulator::push_halt)
        .def("push_load_op", &Emulator::push_load_op)
        .def("push_load_w_op", &Emulator::push_load_w_op)
        .def("push_store_op", &Emulator::push_store_op)
        .def("push_ntt_op", &Emulator::push_ntt_op)
        .def("push_alu_op", &Emulator::push_alu_op)
        .def("push_read_perf_op", &Emulator::push_read_perf_op)
        .def("run", &Emulator::run)
        .def("start_trace", &Emulator::start_trace)
        .def("stop_trace", &Emulator::stop_trace);
}
