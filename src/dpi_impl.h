#ifndef DPI_IMPL_H
#define DPI_IMPL_H

#include <vector>
#include <map>
#include <cstdint>
#include <iostream>
#include "isa_spec.h" 

class VirtualRAM {
    std::map<uint64_t, std::vector<uint64_t>> storage;
public:
    void write(uint64_t addr, const std::vector<uint64_t>& data) {
        storage[addr] = data;
    }
    
    std::vector<uint64_t> read(uint64_t addr, size_t size) {
        if (storage.find(addr) == storage.end()) {
            return std::vector<uint64_t>(size, 0);
        }
        return storage[addr];
    }
};

// Глобальные указатели (определены в emulator_core.cpp)
extern VirtualRAM* g_ram;
extern CommandQueue* g_queue;

#endif // DPI_IMPL_H
