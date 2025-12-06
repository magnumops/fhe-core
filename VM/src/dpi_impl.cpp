
#include <map>
#include <iostream>
#include <stdint.h>
#include "svdpi.h"

static std::map<long long, long long> ram_storage;

// --- ACTUAL IMPLEMENTATION ---
extern "C" void dpi_write_ram(long long addr, long long val) {
    ram_storage[addr] = val;
}

extern "C" long long dpi_read_ram(long long addr) {
    if (ram_storage.find(addr) != ram_storage.end()) {
        return ram_storage[addr];
    }
    return 0;
}

// --- ALIASES (FORWARDERS) FOR COMPATIBILITY ---
// Если кто-то ищет py_write_ram, перенаправляем на dpi_write_ram
extern "C" void py_write_ram(long long addr, long long val) {
    dpi_write_ram(addr, val);
}

extern "C" long long py_read_ram(long long addr) {
    return dpi_read_ram(addr);
}
