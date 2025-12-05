# Криминалистический Отчет: Phase 3 (RNS & Architecture)

Этот документ фиксирует каждую ошибку, сбой сборки и логический тупик, возникший в ходе Фазы 3.

## Хронология Итераций и Ошибок

| ID | День | Действие / Гипотеза | Симптом / Ошибка | Анализ Провала (Root Cause) |
| :--- | :--- | :--- | :--- | :--- |
| **P3-01** | Day 3 | Обновление RTL для `mu`. | Self-Correction. | Логическая ошибка: забыл пробросить `q` и `n_inv`. |
| **P3-02** | Day 3 | Обновление конфига `ntt_config_4k.py`. | `AttributeError: no attribute 'N_LOG'` | **Stale Cache:** Docker `COPY` перенес старый `__pycache__`, Python игнорировал изменения в `.py`. |
| **P3-03** | Day 3 | Исправление конфига + Clean Build. | `bash: VM/.dockerignore: No such file` | **Navigation Error:** Команда выполнялась из `~/fhe-core/VM`, но использовала пути как из корня. |
| **P3-04** | Day 4 | Сборка Docker с новым C++ API. | `AttributeError: 'Emulator' has no attribute 'run_ntt'` | **API Break:** Тест использовал старый метод `run_ntt`, удаленный из C++. |
| **P3-05** | Day 4 | Исправление теста (Wrong Path). | `AttributeError` (Error Persisted). | **Navigation Error:** Файл теста был записан в ошибочную вложенную папку `VM/tests/...`. |
| **P3-06** | Day 4 | Исправление теста (Correct Path). | `stack smashing detected` | **ABI Mismatch:** C++ DPI функция ожидала `svBitVecVal*`, а Verilator передавал `svOpenArrayHandle`. |
| **P3-07** | Day 5 | Git Checkpoint. | `pathspec ... did not match` | **Navigation Error:** Попытка добавить файлы по полным путям, находясь в подпапке. |
| **P3-08** | Day 5 | RTL Compilation. | `Warning-WIDTH` (3 bits vs 2 bits). | **Type Mismatch:** Индексация массива `mem[4]` 3-битным регистром `current_slot`. |
| **P3-09** | Day 5 | C++ Compilation. | `error: 'OPC_LOAD' was not declared`. | **Stale Header:** Файл `isa_spec.h` не обновился из-за ошибки путей в предыдущем шаге. |
| **P3-10** | Day 5 | Linking. | `undefined symbol ..._eval`. | **Verilator Split:** Большой RTL разбился на файлы, не включенные в CMake. Решение: `--output-split 0`. |
| **P3-11** | Day 5 | Runtime Test. | `Logos Core Timeout`. | **Simulation Freeze:** Эмулятор завис, причины не видны. |
| **P3-12** | Day 5 | Debug Instrumentation. | `syntax error, unexpected always`. | **Verilog Syntax:** Попытка вложить `always` блок внутрь другого `always` через `sed`. |
| **P3-13** | Day 5 | Debug Linking. | `undefined symbol: sc_time_stamp`. | **Missing Hook:** Verilator требует функцию `double sc_time_stamp()` при использовании `$time`. |
| **P3-14** | Day 6 | SDK Creation. | `python3: can't open file` | **Navigation Error:** Файл SDK создан во вложенной папке `VM/src/python`, не попал в Docker образ. |
| **P3-15** | Day 7 | Integration Test. | **Mismatch** (Cycles: 0 in INTT). | **Sticky Halt:** Эмулятор остался в состоянии HALT после первой операции. Требуется сброс FSM. |
| **P3-16** | Day 7 | Fix Sticky Halt. | `UnboundLocalError: 'rev'`. | **Copy-Paste Error:** Синтаксическая ошибка в Python коде (`_bit_reverse`), пропущена инициализация переменных. |
| **P3-17** | Day 7 | Final Verify. | **Mismatch** (Data differs). | **Verification Logic Error:** Тест выполняет лишнюю перестановку битов после скачивания результата, хотя аппаратный INTT (DIT) выдает Natural order (согласно тестам Фазы 2). |
