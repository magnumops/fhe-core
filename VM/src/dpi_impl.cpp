#include "dpi_impl.h"
#include "svdpi.h" // Стандартный хедер SystemVerilog DPI
#include <cstring>
#include <iostream>

// Примечание: g_ram определяется в emulator_core.cpp, здесь он только используется (extern).

extern "C" {
    
    // DPI Read: Verilog (Client) reads from C++ RAM (Server)
    // Signature: function void dpi_read_burst(input longint addr, input int len, output bit [63:0] data []);
    // C++ Mapping for open array: const svOpenArrayHandle
    void dpi_read_burst(long long addr, int len, const svOpenArrayHandle data) {
        if (!g_ram) {
            // Safety check: if RAM not initialized, fill with zeros
            return; 
        }
        
        // 1. Читаем данные из модели памяти
        std::vector<uint64_t> vec = g_ram->read(addr, len);
        
        // 2. Копируем в Verilog Open Array
        for (int i = 0; i < len; ++i) {
            // svGetArrElemPtr1 возвращает указатель на элемент массива.
            // Элемент bit [63:0] в C++ представляется как svBitVecVal[2] (2 * 32 бита).
            svBitVecVal* elem = (svBitVecVal*)svGetArrElemPtr1(data, i);
            
            if (elem) {
                uint64_t val = vec[i];
                elem[0] = (svBitVecVal)(val & 0xFFFFFFFF);         // Low 32 bits
                elem[1] = (svBitVecVal)((val >> 32) & 0xFFFFFFFF); // High 32 bits
            }
        }
    }

    // DPI Write: Verilog (Client) writes to C++ RAM (Server)
    // Signature: function void dpi_write_burst(input longint addr, input int len, input bit [63:0] data []);
    void dpi_write_burst(long long addr, int len, const svOpenArrayHandle data) {
        if (!g_ram) return;
        
        std::vector<uint64_t> vec;
        vec.reserve(len);
        
        for (int i = 0; i < len; ++i) {
            svBitVecVal* elem = (svBitVecVal*)svGetArrElemPtr1(data, i);
            if (elem) {
                // Собираем 64-битное число из двух 32-битных чанков
                uint64_t val = (uint64_t)elem[0] | ((uint64_t)elem[1] << 32);
                vec.push_back(val);
            } else {
                vec.push_back(0);
            }
        }
        
        g_ram->write(addr, vec);
    }
}
