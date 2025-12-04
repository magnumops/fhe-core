#include <iostream>
#include <fcntl.h>
#include <sys/mman.h>
#include <unistd.h>
#include <chrono>
#include <cstring>
#include <cerrno>

// 1 Терабайт
const size_t MEM_SIZE = 1ULL * 1024 * 1024 * 1024 * 1024; 

int main() {
    std::cout << "--- Starting 1TB Mmap Spike ---" << std::endl;

    const char* filepath = "virtual_ram.bin";

    // 1. Открываем файл
    int fd = open(filepath, O_RDWR | O_CREAT | O_TRUNC, 0666);
    if (fd == -1) {
        std::cerr << "Error opening file: " << strerror(errno) << std::endl;
        return 1;
    }

    // 2. Растягиваем до 1 ТБ (Sparse File - на диске займет 0 байт)
    std::cout << "[1] Allocating 1TB sparse file..." << std::endl;
    if (ftruncate(fd, MEM_SIZE) == -1) {
        std::cerr << "Error ftruncate: " << strerror(errno) << std::endl;
        return 1;
    }

    // 3. Маппим в память
    std::cout << "[2] Mapping to RAM..." << std::endl;
    void* map = mmap(0, MEM_SIZE, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0);
    if (map == MAP_FAILED) {
        std::cerr << "Error mmap: " << strerror(errno) << std::endl;
        return 1;
    }

    uint8_t* ram = (uint8_t*)map;

    // 4. Тест записи (Benchmark)
    std::cout << "[3] Writing data to random locations..." << std::endl;
    auto start = std::chrono::high_resolution_clock::now();

    // Пишем в начало
    ram[0] = 0xAA;
    
    // Пишем в середину (500 ГБ)
    size_t offset_mid = MEM_SIZE / 2;
    ram[offset_mid] = 0xBB;

    // Пишем в самый конец (1 ТБ - 1 байт)
    size_t offset_end = MEM_SIZE - 1;
    ram[offset_end] = 0xCC;

    // Принудительная синхронизация с диском (чтобы проверить реальную запись)
    msync(map, MEM_SIZE, MS_SYNC);

    auto end = std::chrono::high_resolution_clock::now();
    std::chrono::duration<double> diff = end - start;

    std::cout << "[4] Verification:" << std::endl;
    std::cout << "    Addr 0: " << std::hex << (int)ram[0] << std::endl;
    std::cout << "    Addr 500GB: " << (int)ram[offset_mid] << std::endl;
    std::cout << "    Addr 1TB: " << (int)ram[offset_end] << std::dec << std::endl;

    std::cout << "--- Spike Complete ---" << std::endl;
    std::cout << "Time taken: " << diff.count() << " seconds" << std::endl;

    // Очистка
    munmap(map, MEM_SIZE);
    close(fd);
    // Удаляем файл, чтобы не мусорить в контейнере
    unlink(filepath); 
    
    return 0;
}
