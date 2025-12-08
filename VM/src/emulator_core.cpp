#include <pybind11/pybind11.h>
#include <iostream>
#include <map>
#include <vector>
#include <memory>
#include "verilated.h"
#include "Vlogos_core.h"
#include "svdpi.h"

using namespace std;

static map<long long, long long> global_ram;
static Vlogos_core* top = nullptr;
static vluint64_t main_time = 0;

// Dual Shadow Memory (Slot 0 and Slot 1)
static vector<uint64_t> slot0(4096, 0);
static vector<uint64_t> slot1(4096, 0);
static uint64_t poly_modulus = 0; // Will be loaded from Python or default

extern "C" {
    void init_ram() { global_ram.clear(); }
    void cleanup_ram() { global_ram.clear(); if(top) { top->final(); delete top; top=nullptr; } }
    
    void write_ram(long long addr, long long data) { global_ram[addr] = data; }
    
    long long read_ram(long long addr) {
        long long val = global_ram.count(addr) ? global_ram[addr] : 0;
        
        // --- SNOOPING LOGIC (Address based slot mapping) ---
        // 0x1000 range -> Slot 0
        // 0x2000 range -> Slot 1
        uint64_t offset;
        if (addr >= 0x1000 && addr < 0x2000) {
            offset = (addr - 0x1000) / 8;
            if(offset < 4096) slot0[offset] = val;
        }
        else if (addr >= 0x2000 && addr < 0x3000) {
            offset = (addr - 0x2000) / 8;
            if(offset < 4096) slot1[offset] = val;
        }
        return val;
    }

    void py_write_ram(long long addr, long long val) { global_ram[addr] = val; }
    long long py_read_ram(long long addr) { return global_ram.count(addr) ? global_ram[addr] : 0; }
    void py_set_modulus(long long mod) { poly_modulus = mod; }

    void dpi_exec_alu(int opcode, int slot, int count) {
        printf("[DPI] ALU Opcode=%d\n", opcode);
        
        // Opcode 6: SUB (Slot0 - Slot1) -> Result RAM
        if (opcode == 6) { 
            for(int i=0; i<4096; i++) {
                // (A - B + P) % P
                uint64_t val_a = slot0[i];
                uint64_t val_b = slot1[i];
                uint64_t res = (val_a >= val_b) ? (val_a - val_b) : (val_a + poly_modulus - val_b);
                res %= poly_modulus;
                
                // Write to Result area (0x8000) AND update Slot0 for chaining
                global_ram[0x8000 + i*8] = res;
                slot0[i] = res; // Accumulator behavior
            }
            printf("[DPI] SUB Executed. Result in Slot0 & RAM 0x8000\n");
        }
        // Opcode 7: MULT (Slot0 * Slot1 OR Slot0 * Slot0 if Slot1 empty?)
        // For PSI "Difference Square", we need to square the result of SUB.
        // Since SUB updated Slot0, we can just Multiply Slot0 * Slot0.
        else if (opcode == 7) {
            for(int i=0; i<4096; i++) {
                unsigned __int128 temp = (unsigned __int128)slot0[i] * slot0[i];
                uint64_t res = (uint64_t)(temp % poly_modulus);
                global_ram[0x8000 + i*8] = res;
            }
             printf("[DPI] SQUARE (Slot0) Executed. Result in RAM 0x8000\n");
        }
    }
}

double sc_time_stamp() { return main_time; }

class LogosSim {
public:
    LogosSim() { if(!top) { top = new Vlogos_core; Verilated::traceEverOn(true); init_ram(); } }
    ~LogosSim() { cleanup_ram(); }
    void reset_state() { top->rst=1; tick(); tick(); top->rst=0; top->cmd_valid=0; tick(); }
    void push_command(uint32_t op, uint32_t slot, uint64_t addr, uint32_t t) {
        top->cmd_valid=1; top->cmd_opcode=op; top->cmd_slot=slot;
        top->cmd_dma_addr=addr; top->cmd_target=t;
        tick();
        top->cmd_valid=0; top->cmd_opcode=0;
    }
    void tick() { top->clk=1; top->eval(); main_time++; top->clk=0; top->eval(); main_time++; }
    uint64_t get_ticks() { return main_time; }
};

namespace py = pybind11;
PYBIND11_MODULE(logos_emu, m) {
    py::class_<LogosSim>(m, "LogosContext")
        .def(py::init<>()).def("reset_state", &LogosSim::reset_state)
        .def("tick", &LogosSim::tick).def("push_command", &LogosSim::push_command)
        .def("get_ticks", &LogosSim::get_ticks);
    m.def("write_ram", [](long long a, long long v) { py_write_ram(a, v); });
    m.def("read_ram", [](long long a) { return py_read_ram(a); });
    m.def("set_modulus", [](long long m) { py_set_modulus(m); });
}
