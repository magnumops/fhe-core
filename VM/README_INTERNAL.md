# Logos FHE Emulator (Phase 2: NTT Engine)

## Архитектура v2.0
Проект реализует аппаратный ускоритель для Number Theoretic Transform (NTT), используемый в схеме BFV.
1.  **Level 1: Python SDK** — Генерирует данные, выполняет Bit-Reversal перестановку (DIT требование) и управляет DMA.
2.  **Level 2: C++ Driver (`emulator_core.cpp`)** — Управляет тактированием Verilator и передает данные через DPI.
3.  **Level 3: Memory (`dpi_impl.cpp`)** — Виртуальная память (Sparse Map), доступная из Verilog через DPI Open Arrays.
4.  **Level 4: Hardware (`src/rtl/ntt/*.v`)**:
    *   `ntt_engine.v`: Top-level ядро. Поддерживает режимы NTT (Mode 0) и INTT (Mode 1).
    *   `ntt_control.v`: Address Generation Unit (AGU) для алгоритма Cooley-Tukey.
    *   `butterfly.v`: Вычислительное ядро (Modular Add/Sub/Mult).
    *   `twiddle_rom.v`: Память поворотных множителей (8192 слова: 4K прямых + 4K обратных).

## Параметры (N=4096)
*   **N:** 4096
*   **Modulus (Q):** 1073750017 (30-bit prime)
*   **Root (Psi):** 996876704
*   **Algorithm:** Radix-2 Decimation-in-Time (DIT).
    *   Input: Bit-Reversed Order.
    *   Output: Natural Order.

## Запуск Тестов
\`\`\`bash
cd VM
docker build -t logos-emu .
\`\`\`
Dockerfile автоматически запускает финальный тест `tests/test_day10_platinum.py`.
