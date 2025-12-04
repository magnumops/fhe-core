#include <iostream>
#include <sys/mman.h>
#include <fcntl.h>
#include <unistd.h>
#include <cstring>
#include "svdpi.h" // Хедер для DPI (из Verilator)

// --- Класс Виртуальной Памяти (упрощенный из Дня 5) ---
class VirtualRAM {
public:
    uint64_t* ram_base;
    size_t size_bytes;
    int fd;

    VirtualRAM() {
        // 1GB для тестов (можно 1TB, но для теста хватит)
        size_bytes = 1024 * 1024 * 1024; 
        
        fd = open("verilator_ram.bin", O_RDWR | O_CREAT | O_TRUNC, 0666);
        ftruncate(fd, size_bytes);
        
        void* map = mmap(0, size_bytes, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0);
        ram_base = (uint64_t*)map;
        
        // Очистка при старте
        memset(ram_base, 0, 1024); // Чистим первый килобайт
    }

    ~VirtualRAM() {
        munmap(ram_base, size_bytes);
        close(fd);
        unlink("verilator_ram.bin");
    }

    uint64_t read(uint64_t addr) {
        // Простейшая защита границ
        if (addr >= (size_bytes / 8)) return 0xDEADBEEF;
        return ram_base[addr];
    }

    void write(uint64_t addr, uint64_t val) {
        if (addr >= (size_bytes / 8)) return;
        ram_base[addr] = val;
    }
};

// Глобальный указатель на память (Singleton)
// Нужен, так как DPI функции - это обычные C функции
VirtualRAM* g_ram = nullptr;

// --- DPI Функции (экспортируемые в Verilog) ---
extern "C" {

    // Эту функцию вызывает Verilog
    long long dpi_read_ram(long long addr) {
        if (!g_ram) return 0;
        return (long long)g_ram->read((uint64_t)addr);
    }

}

// --- Функции управления для Python (через PyBind) ---
// Инициализация памяти перед запуском симуляции
void init_ram() {
    if (!g_ram) g_ram = new VirtualRAM();
}

void cleanup_ram() {
    if (g_ram) {
        delete g_ram;
        g_ram = nullptr;
    }
}

// Запись в память из Python (Backdoor access)
void py_write_ram(uint64_t addr, uint64_t val) {
    if (g_ram) g_ram->write(addr, val);
}
