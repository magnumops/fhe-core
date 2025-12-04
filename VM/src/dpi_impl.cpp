#include <iostream>
#include <sys/mman.h>
#include <fcntl.h>
#include <unistd.h>
#include <cstring>
#include "svdpi.h" 

class VirtualRAM {
public:
    uint64_t* ram_base;
    size_t size_bytes;
    int fd;

    VirtualRAM() {
        size_bytes = 1024 * 1024 * 1024; 
        fd = open("verilator_ram.bin", O_RDWR | O_CREAT, 0666);
        ftruncate(fd, size_bytes);
        void* map = mmap(0, size_bytes, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0);
        ram_base = (uint64_t*)map;
    }

    ~VirtualRAM() {
        munmap(ram_base, size_bytes);
        close(fd);
        unlink("verilator_ram.bin");
    }

    uint64_t read(uint64_t addr) {
        if (addr >= (size_bytes / 8)) return 0;
        return ram_base[addr];
    }

    void write(uint64_t addr, uint64_t val) {
        if (addr >= (size_bytes / 8)) return;
        ram_base[addr] = val;
    }
};

VirtualRAM* g_ram = nullptr;

extern "C" {
    long long dpi_read_ram(long long addr) {
        if (!g_ram) return 0;
        return (long long)g_ram->read((uint64_t)addr);
    }

    // Чтение (RAM -> Verilog)
    void dpi_read_burst(long long addr, int len, const svOpenArrayHandle data) {
        if (!g_ram) return;
        for (int i = 0; i < len; i++) {
            uint64_t val = g_ram->read(addr + i);
            uint64_t* v_ptr = (uint64_t*)svGetArrElemPtr1(data, i);
            if (v_ptr) *v_ptr = val;
        }
    }

    // Запись (Verilog -> RAM) -- НОВОЕ
    void dpi_write_burst(long long addr, int len, const svOpenArrayHandle data) {
        if (!g_ram) return;
        for (int i = 0; i < len; i++) {
            uint64_t* v_ptr = (uint64_t*)svGetArrElemPtr1(data, i);
            if (v_ptr) {
                g_ram->write(addr + i, *v_ptr);
            }
        }
    }
}

void init_ram() { if (!g_ram) g_ram = new VirtualRAM(); }
void cleanup_ram() { if (g_ram) { delete g_ram; g_ram = nullptr; } }
void py_write_ram(uint64_t addr, uint64_t val) { if (g_ram) g_ram->write(addr, val); }

// НОВОЕ: Функция для чтения памяти из Python (чтобы проверить результат)
uint64_t py_read_ram(uint64_t addr) { 
    if (g_ram) return g_ram->read(addr); 
    return 0;
}
