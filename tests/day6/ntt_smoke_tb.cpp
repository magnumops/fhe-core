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
    
    // Параметры
    top->q = 0x0800000000000001;
    top->mu = 0; 
    top->n_inv = 0;
    top->cmd_valid = 0;

    std::cout << "Starting Simulation..." << std::endl;

    // Reset Sequence
    for (int i = 0; i < 10; i++) {
        top->clk = !top->clk;
        top->eval();
        main_time++;
    }
    top->rst = 0;
    
    // Run loop
    bool ready_detected = false;
    for (int i = 0; i < 100; i++) {
        top->clk = !top->clk;
        top->eval();
        main_time++;
        
        if (top->clk == 1 && top->ready == 1) {
            ready_detected = true;
            std::cout << "Core became READY at cycle " << i/2 << std::endl;
            break;
        }
    }

    if (ready_detected) 
        std::cout << "SUCCESS: NTT Engine reset and ready." << std::endl;
    else 
        std::cout << "FAILURE: NTT Engine stuck." << std::endl;

    top->final();
    delete top;
    return 0;
}
