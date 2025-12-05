#pragma once
#include <cstdint>
#include <queue>
#include <mutex>

// --- Opcodes ---
const uint8_t OPC_HALT   = 0x00;
const uint8_t OPC_CONFIG = 0x01;
const uint8_t OPC_LOAD   = 0x02;
const uint8_t OPC_STORE  = 0x03;
const uint8_t OPC_LOAD_W = 0x04;
const uint8_t OPC_READ_PERF = 0x0F; // Performance Counters

const uint8_t OPC_NTT    = 0x10;
const uint8_t OPC_INTT   = 0x11;

const uint8_t OPC_ADD    = 0x20;
const uint8_t OPC_SUB    = 0x21;
const uint8_t OPC_MULT   = 0x22;

// --- Command Queue (Thread-Safe) ---
class CommandQueue {
    std::queue<uint64_t> q;
    std::mutex mtx;
public:
    void push(uint64_t cmd) {
        std::lock_guard<std::mutex> lock(mtx);
        q.push(cmd);
    }
    bool pop(uint64_t& cmd) {
        std::lock_guard<std::mutex> lock(mtx);
        if (q.empty()) return false;
        cmd = q.front();
        q.pop();
        return true;
    }
    void clear() {
        std::lock_guard<std::mutex> lock(mtx);
        std::queue<uint64_t> empty;
        std::swap(q, empty);
    }
};
