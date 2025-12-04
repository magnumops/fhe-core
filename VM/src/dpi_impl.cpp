#include "dpi_impl.h"
#include <iostream>
#include <map>
#include <deque>
#include <vector>
#include <svdpi.h> 

// === GLOBAL STATE ===
static std::map<uint64_t, uint8_t> g_memory;
static std::deque<uint64_t> g_cmd_queue;

// === MEMORY METHODS ===
void VirtualRAM::write(uint64_t addr, const std::vector<uint64_t>& data) {
    for (size_t i = 0; i < data.size(); ++i) {
        uint64_t val = data[i];
        uint64_t byte_addr = (addr + i) * 8;
        for (int b = 0; b < 8; ++b) {
            g_memory[byte_addr + b] = (val >> (b * 8)) & 0xFF;
        }
    }
}

std::vector<uint64_t> VirtualRAM::read(uint64_t addr, size_t size) {
    std::vector<uint64_t> res(size);
    for (size_t i = 0; i < size; ++i) {
        uint64_t val = 0;
        uint64_t byte_addr = (addr + i) * 8;
        for (int b = 0; b < 8; ++b) {
            if (g_memory.count(byte_addr + b)) {
                val |= ((uint64_t)g_memory[byte_addr + b] << (b * 8));
            }
        }
        res[i] = val;
    }
    return res;
}

// === COMMAND QUEUE METHODS ===
void CommandQueue::push(uint64_t cmd) {
    g_cmd_queue.push_back(cmd);
}

void CommandQueue::clear() {
    g_cmd_queue.clear();
}

// === DPI EXPORTS ===

// 1. Burst Read (Using Open Array Handle - CORRECT SIGNATURE)
extern "C" void dpi_read_burst(long long addr, int len, const svOpenArrayHandle h) {
    for (int i = 0; i < len; ++i) {
        uint64_t val = 0;
        uint64_t byte_addr = (addr + i) * 8;
        for (int b = 0; b < 8; ++b) {
             if (g_memory.count(byte_addr + b)) {
                val |= ((uint64_t)g_memory[byte_addr + b] << (b * 8));
             }
        }
        
        // Get pointer to Verilog array element
        svBitVecVal* ptr = (svBitVecVal*)svGetArrElemPtr1(h, i);
        if (ptr) {
            ptr[0] = (uint32_t)(val & 0xFFFFFFFF);
            ptr[1] = (uint32_t)(val >> 32);
        }
    }
}

// 2. Burst Write (Using Open Array Handle - CORRECT SIGNATURE)
extern "C" void dpi_write_burst(long long addr, int len, const svOpenArrayHandle h) {
    for (int i = 0; i < len; ++i) {
        svBitVecVal* ptr = (svBitVecVal*)svGetArrElemPtr1(h, i);
        if (!ptr) continue;
        
        uint64_t val = (uint64_t)ptr[0] | ((uint64_t)ptr[1] << 32);
        uint64_t byte_addr = (addr + i) * 8;
        for (int b = 0; b < 8; ++b) {
            g_memory[byte_addr + b] = (val >> (b * 8)) & 0xFF;
        }
    }
}

// 3. Get Command (Simple pointer, NO Open Array)
extern "C" svLogic dpi_get_cmd(svBitVecVal* cmd_out) {
    if (g_cmd_queue.empty()) {
        return 0; // Logic 0
    }
    uint64_t cmd = g_cmd_queue.front();
    g_cmd_queue.pop_front();
    
    cmd_out[0] = (uint32_t)(cmd & 0xFFFFFFFF);
    cmd_out[1] = (uint32_t)(cmd >> 32);
    return 1; // Logic 1
}
