#include "Vntt_engine.h"
#include "verilated.h"
#include <iostream>

vluint64_t main_time = 0;
double sc_time_stamp() { return main_time; }

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    Vntt_engine* top = new Vntt_engine;

    // Инициализация
    top->clk = 0;
    top->rst = 1;
    top->cmd_valid = 0;
    
    // Mock Arbiter Response
    top->arb_gnt = 0;
    top->arb_valid = 0;

    std::cout << "Starting V2 Simulation..." << std::endl;

    // Reset
    for (int i = 0; i < 10; i++) {
        top->clk = !top->clk; top->eval(); main_time++;
    }
    top->rst = 0;
    
    // --- TEST 1: Check IDLE/READY ---
    bool ready_ok = false;
    for (int i = 0; i < 20; i++) {
        top->clk = !top->clk; top->eval(); main_time++;
        if (top->clk==1 && top->ready==1) ready_ok = true;
    }
    if (!ready_ok) { std::cout << "FAIL: Core not ready" << std::endl; return 1; }
    
    // --- TEST 2: Send LOAD Command (Check Arbiter Request) ---
    // Opcode LOAD = 0x02
    top->cmd_valid = 1;
    top->cmd_opcode = 0x02; 
    top->cmd_dma_addr = 0x1000;
    
    // Step 1 cycle to latch command
    top->clk = 0; top->eval(); main_time++;
    top->clk = 1; top->eval(); main_time++;
    top->cmd_valid = 0;

    // Wait for arb_req
    bool req_seen = false;
    for (int i = 0; i < 10; i++) {
        top->clk = 0; top->eval(); main_time++;
        
        // Simulate Arbiter Grant
        if (top->arb_req) {
            req_seen = true;
            top->arb_gnt = 1; // Grant immediately
        } else {
            top->arb_gnt = 0;
        }

        top->clk = 1; top->eval(); main_time++;
        
        if (req_seen) break;
    }

    if (req_seen) std::cout << "SUCCESS: DMA Request detected on bus." << std::endl;
    else std::cout << "FAILURE: No DMA Request." << std::endl;

    top->final();
    delete top;
    return 0;
}
