#include "Vcounter.h"   // Заголовочный файл, который сгенерирует Verilator
#include "verilated.h"  // Библиотека Verilator
#include <iostream>

vluint64_t main_time = 0;       // Текущее время симуляции

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    
    // Инстанцируем (создаем) наш модуль
    Vcounter* top = new Vcounter;

    // Инициализация сигналов
    top->clk = 0;
    top->rst = 1; // Держим ресет
    
    std::cout << "--- Starting Verilator Spike ---" << std::endl;

    // Цикл симуляции (10 тактов)
    for (int i = 0; i < 20; i++) {
        // Переключаем клоки (0 -> 1 -> 0)
        top->clk = !top->clk;
        
        // Снимаем ресет на 4-м полутакте
        if (i > 4) top->rst = 0;

        // Вычисляем логику (самое важное!)
        top->eval();

        // Вывод на каждом позитивном фронте (когда clk стал 1)
        if (top->clk == 1) {
            std::cout << "Cycle " << (i/2) 
                      << " | Reset: " << (int)top->rst 
                      << " | Count: " << (int)top->count << std::endl;
        }
    }

    std::cout << "--- Spike Complete ---" << std::endl;
    
    // Очистка
    top->final();
    delete top;
    return 0;
}
