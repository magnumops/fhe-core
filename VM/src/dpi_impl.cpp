#include "dpi_impl.h"
#include "verilated_dpi.h" 

extern "C" {

    unsigned char dpi_get_cmd(svBitVecVal* cmd_out) {
        if (!g_queue) return 0;
        uint64_t raw_cmd;
        if (g_queue->pop(raw_cmd)) {
            cmd_out[0] = (uint32_t)(raw_cmd & 0xFFFFFFFF);
            cmd_out[1] = (uint32_t)(raw_cmd >> 32);
            return 1; 
        }
        return 0; 
    }

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

    void dpi_write_burst(long long addr, int len, const svOpenArrayHandle h) {
        if (!g_ram) return;
        std::vector<uint64_t> data(len);
        for (int i = 0; i < len; i++) {
             svBitVecVal* elem = (svBitVecVal*)svGetArrElemPtr1(h, i);
             if (elem) {
                 uint64_t low = elem[0];
                 uint64_t high = elem[1];
                 data[i] = low | (high << 32);
             } else {
                 data[i] = 0;
             }
        }
        g_ram->write(addr, data);
    }
}
