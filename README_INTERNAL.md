# Logos FHE Emulator (MVP)

## Архитектура
Проект реализует гибридную эмуляцию FHE-ускорителя:
1.  **Level 1: Python SDK (`src/python/logos.py`)** — Высокоуровневый интерфейс, Shadow Execution.
2.  **Level 2: C++ Bridge (`src/emulator_core.cpp`)** — Связывает Python, SEAL и Verilator через PyBind11.
3.  **Level 3: Crypto Engine (`src/fhe_impl.cpp`)** — Обертка над Microsoft SEAL (BFV Scheme).
4.  **Level 4: Memory (`src/dpi_impl.cpp`)** — Эмуляция 1 ТБ памяти через `mmap` (Sparse Files).
5.  **Level 5: Hardware (`src/rtl/*.v`)** — Verilog-модели, исполняемые через Verilator.

## Как запускать
Проект полностью контейнеризирован.

### Сборка и Тесты
\`\`\`bash
cd VM
docker build -t logos-emu .
\`\`\`
Эта команда:
1.  Соберет окружение (Ubuntu, CMake, Verilator, Python).
2.  Скомпилирует SEAL (кэшируется).
3.  Соберет проект `logos_vm`.
4.  Запустит финальный тест `tests/test_day10_final.py`.

### Ручной запуск (внутри контейнера)
\`\`\`bash
docker run -it logos-emu /bin/bash
# Внутри:
python3 tests/test_day10_final.py
\`\`\`

## Структура
*   `VM/src/rtl/` — Исходники "железа" (Verilog).
*   `VM/src/python/` — Python SDK.
*   `VM/src/*.cpp` — C++ ядро эмулятора.
*   `VM/tests/` — Интеграционные тесты.
