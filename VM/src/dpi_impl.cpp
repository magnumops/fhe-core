#include "dpi_impl.h"
#include "verilated_dpi.h" 
#include <iostream>

extern "C" {

    // FIXED SIGNATURE: Matches 'function bit dpi_get_cmd(output bit [63:0] cmd_out)'
    unsigned char dpi_get_cmd(svBitVecVal* cmd_out) {
        if (!g_queue) return 0;
        
        uint64_t raw_cmd;
        if (g_queue->pop(raw_cmd)) {
            // Pack 64-bit command into Verilator's svBitVecVal (2x 32-bit chunks)
            cmd_out[0] = (uint32_t)(raw_cmd & 0xFFFFFFFF);
            cmd_out[1] = (uint32_t)(raw_cmd >> 32);
            return 1; // Valid
        }
        return 0; // Empty
    }

    // SAFE 64-bit Read
    void dpi_read_burst(long long addr, int len, const svOpenArrayHandle h) {
        if (!g_ram) return;
        std::vector<uint64_t> data = g_ram->read(addr, len);
        for (int i = 0; i < len; i++) {
            svBitVecVal* elem = (svBitVecVal*)svGetArrElemPtr1(h, i);
            if (elem) {
                elem[0] = (uint32_t)(data[i] & 0xFFFFFFFF);
                elem[1] = (uint32_t)(data[i] >> 32);
            }
        }
    }

    // SAFE 64-bit Write (With Debug for Perf Dump)
    void dpi_write_burst(long long addr, int len, const svOpenArrayHandle h) {
        if (!g_ram) return;
        std::vector<uint64_t> data(len);
        
        // Debug only small writes (likely Perf Dump)
        bool debug_mode = (len == 4); 

        for (int i = 0; i < len; i++) {
             svBitVecVal* elem = (svBitVecVal*)svGetArrElemPtr1(h, i);
             if (elem) {
                 uint64_t low = elem[0];
                 uint64_t high = elem[1];
                 data[i] = low | (high << 32);
                 
                 if (debug_mode && data[i] > 0) {
                     std::cout << "[DPI] PerfCounter[" << i << "] = " << data[i] << std::endl;
                 }
             } else {
                 data[i] = 0;
             }
        }
        g_ram->write(addr, data);
    }
}
