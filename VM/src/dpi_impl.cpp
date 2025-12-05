#include <iostream>
#include <map>
#include "svdpi.h" 

class VirtualRAM {
public:
    std::map<long long, long long> memory; // Используем signed для совместимости с DPI
    long long read(long long addr) { return memory[addr]; }
    void write(long long addr, long long val) { memory[addr] = val; }
};

VirtualRAM* g_ram = nullptr;

void init_ram() { if (!g_ram) g_ram = new VirtualRAM(); }
void cleanup_ram() { if (g_ram) { delete g_ram; g_ram = nullptr; } }

extern "C" {
    // Single read (Verilog -> C++)
    long long dpi_read_ram(long long addr) {
        if (!g_ram) return 0;
        return g_ram->read(addr);
    }

    // Burst Read (RAM -> Verilog)
    void dpi_read_burst(long long addr, int len, const svOpenArrayHandle data) {
        if (!g_ram) return;
        for (int i = 0; i < len; i++) {
            long long val = g_ram->read(addr + i);
            svBitVecVal* v_ptr = (svBitVecVal*)svGetArrElemPtr1(data, i);
            if (v_ptr) {
                v_ptr[0] = (uint32_t)(val & 0xFFFFFFFF);
                v_ptr[1] = (uint32_t)(val >> 32);
            }
        }
    }

    // Burst Write (Verilog -> RAM)
    void dpi_write_burst(long long addr, int len, const svOpenArrayHandle data) {
        if (!g_ram) return;
        for (int i = 0; i < len; i++) {
            svBitVecVal* v_ptr = (svBitVecVal*)svGetArrElemPtr1(data, i);
            if (v_ptr) {
                long long val = (long long)v_ptr[0] | ((long long)v_ptr[1] << 32);
                g_ram->write(addr + i, val);
            }
        }
    }
    
    // Backdoor Write (Python/Verilog -> C++)
    // ВАЖНО: Должна быть здесь, так как Verilog импортирует её как DPI-C
    void py_write_ram(long long addr, long long val) {
        if (!g_ram) init_ram();
        g_ram->write(addr, val);
    }
}

// Helper for Python (Not DPI, purely C++)
long long py_read_ram(long long addr) {
    if (!g_ram) return 0;
    return g_ram->read(addr);
}
