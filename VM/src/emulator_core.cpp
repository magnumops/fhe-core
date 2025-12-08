#include <pybind11/pybind11.h>
#include <iostream>
#include <map>
#include <vector>
#include <memory>
#include <verilated.h>
#include <verilated_vcd_c.h>
#include "Vlogos_core.h"
#include "svdpi.h"
#include "seal/seal.h"

using namespace seal;
using namespace std;

// --- Global State ---
static map<long long, long long> global_ram;
static Vlogos_core* top = nullptr;
static vluint64_t main_time = 0;

static vector<uint64_t> shadow_mem(4096, 0);
static size_t load_ptr = 0;
static unique_ptr<SEALContext> seal_context;
static uint64_t poly_modulus = 0;

void init_seal_env() {
    EncryptionParameters parms(scheme_type::bfv);
    parms.set_poly_modulus_degree(4096);
    parms.set_coeff_modulus(CoeffModulus::Create(4096, { 60 }));
    // FIX: Синхронизируем параметры с генератором
    parms.set_plain_modulus(PlainModulus::Batching(4096, 20));
    
    seal_context = make_unique<SEALContext>(parms);
    auto moduli = parms.coeff_modulus();
    poly_modulus = moduli[0].value();
}

extern "C" {
    long long read_ram(long long addr) {
        long long val = global_ram.count(addr) ? global_ram[addr] : 0;
        shadow_mem[load_ptr % 4096] = (uint64_t)val;
        load_ptr++;
        return val;
    }

    void write_ram(long long addr, long long data) {
        global_ram[addr] = data;
    }

    void init_ram() { 
        global_ram.clear(); 
        load_ptr = 0;
        init_seal_env();
    }
    
    void cleanup_ram() { 
        global_ram.clear(); 
        if (top) { top->final(); delete top; top = nullptr; }
    }
    
    void py_write_ram(long long addr, long long val) { global_ram[addr] = val; }
    long long py_read_ram(long long addr) { return global_ram.count(addr) ? global_ram[addr] : 0; }

    void dpi_exec_alu(int opcode, int slot, int count) {
        printf("[DPI] ALU Triggered: Opcode=%d\n", opcode);
        load_ptr = 0;
        if (opcode == 7) { // MULT (Square)
            printf("[DPI] Executing SQUARE (A^2 mod q)...\n");
            for(int i=0; i<4096; i++) {
                unsigned __int128 temp = (unsigned __int128)shadow_mem[i] * shadow_mem[i];
                uint64_t res = (uint64_t)(temp % poly_modulus);
                global_ram[0x8000 + i*8] = res;
            }
        }
    }
}

double sc_time_stamp() { return main_time; }

class LogosSim {
public:
    LogosSim() {
        if (!top) { top = new Vlogos_core; Verilated::traceEverOn(true); init_ram(); }
    }
    ~LogosSim() { cleanup_ram(); }
    
    void reset_state() {
        top->rst = 1; tick(); tick(); top->rst = 0; top->cmd_valid = 0; tick();
    }
    
    void push_command(uint32_t op, uint32_t slot, uint64_t addr, uint32_t t) {
        top->cmd_valid = 1; top->cmd_opcode = op; top->cmd_slot = slot;
        top->cmd_dma_addr = addr; top->cmd_target = t;
        tick();
        top->cmd_valid = 0; top->cmd_opcode = 0;
    }
    
    void tick() { top->clk = 1; top->eval(); main_time++; top->clk = 0; top->eval(); main_time++; }
    uint64_t get_ticks() { return main_time; }
};

namespace py = pybind11;
PYBIND11_MODULE(logos_emu, m) {
    py::class_<LogosSim>(m, "LogosContext")
        .def(py::init<>())
        .def("reset_state", &LogosSim::reset_state)
        .def("tick", &LogosSim::tick)
        .def("push_command", &LogosSim::push_command)
        .def("get_ticks", &LogosSim::get_ticks);
    m.def("write_ram", [](long long a, long long v) { py_write_ram(a, v); });
    m.def("read_ram", [](long long a) { return py_read_ram(a); });
}
