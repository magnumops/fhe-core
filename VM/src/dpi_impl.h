#ifndef DPI_IMPL_H
#define DPI_IMPL_H

#include <vector>
#include <cstdint>
#include <cstddef>

class VirtualRAM {
public:
    void write(uint64_t addr, const std::vector<uint64_t>& data);
    std::vector<uint64_t> read(uint64_t addr, size_t size);
};

class CommandQueue {
public:
    void push(uint64_t cmd);
    void clear();
};

#endif
