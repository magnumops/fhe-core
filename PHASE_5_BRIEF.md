# Phase 5: Optimization & Scaling
**Цель:** Достичь ускорения x4 за счет многоядерности и x2 за счет конвейеризации.

## Текущее состояние (v4.0)
*   Архитектура: Single Core, Single Memory Bank.
*   Производительность: ~24k тактов на NTT (4k).
*   Бутылочное горлышко: Compute Bound (почти 100% утилизация ALU).

## План действий
1.  **Dual Core Architecture:**
    *   Дублирование `ntt_engine` (Core 0, Core 1).
    *   Арбитраж доступа к памяти (Memory Interconnect).
2.  **Instruction Level Parallelism (ILP):**
    *   Запуск загрузки данных (DMA) *во время* вычислений (Compute).
    *   Double Buffering (Ping-Pong buffers).
3.  **Advanced RNS:**
    *   Параллельная обработка разных RNS-модулей на разных ядрах.
