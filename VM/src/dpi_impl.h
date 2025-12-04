#pragma once
#include <cstddef> // Fix: Required for size_t
#include <cstdint>
#include <vector>
#include <map>

// Предварительное объявление
class VirtualRAM;

// Глобальный указатель
extern VirtualRAM* g_ram;

class VirtualRAM {
    std::map<uint64_t, uint64_t> memory;
public:
    void write(uint64_t addr, const std::vector<uint64_t>& data) {
        // Fix: std::size_t
        for (std::size_t i = 0; i < data.size(); ++i) {
            memory[addr + i] = data[i];
        }
    }
    
    // Fix: std::size_t
    std::vector<uint64_t> read(uint64_t addr, std::size_t len) {
        std::vector<uint64_t> res;
        res.reserve(len);
        for (std::size_t i = 0; i < len; ++i) {
            if (memory.count(addr + i)) {
                res.push_back(memory[addr + i]);
            } else {
                res.push_back(0); 
            }
        }
        return res;
    }
};
