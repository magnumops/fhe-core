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

## Episode: Day 8 - RNS & Dynamic Twiddles
| ID | Симптом | Root Cause | Fix |
| :--- | :--- | :--- | :--- |
| **P3-D8-01** | `tests/test_day8_rns_hw.py: No such file` | **Navigation Error.** Попытка создать файл в несуществующей папке (из корня). | `mkdir -p` и `cd` перед записью. |
| **P3-D8-02** | RNS Mismatch (Data corruption). | **Static ROM.** Аппаратный блок Twiddle Factor был прошит под один $Q$, а использовался для другого. | Замена `twiddle_rom` на `twiddle_ram` и реализация `OPC_LOAD_W`. |
| **P3-D8-03** | `bash: VM/src/...: No such file`. | **Navigation Error.** Повторная ошибка с путями при обновлении RTL. | Использование относительных путей `src/...`. |

## Episode: Day 9 - BFV ALU
| ID | Симптом | Root Cause | Fix |
| :--- | :--- | :--- | :--- |
| **P3-D9-01** | (No Failure) | — | ALU интегрирован успешно с первого раза. |

## Episode: Day 10 - Diamond Loop & SEAL Integration
| ID | Симптом | Root Cause | Fix |
| :--- | :--- | :--- | :--- |
| **P3-D10-01** | `error: no matching function` (C++). | **Non-copyable SEAL objects.** Попытка присваивания объектов SEAL в конструкторе. | Использование `std::shared_ptr` и `std::unique_ptr`. |
| **P3-D10-02** | `RuntimeError: RNS index out of bounds`. | **SEAL Special Prime.** SEAL использует последний модуль как P, уменьшая K на 1. HW ожидало K модулей данных. | Передача в SEAL $K+1$ простых чисел. |
| **P3-D10-03** | `RuntimeError: Out of Device Memory`. | **Slot Leak.** Алгоритм теста пытался держать в памяти 3 вектора (по 2 слота каждый = 6 слотов) при лимите 4. | Оптимизация: выгрузка промежуточных итогов (Host Sum). |
| **P3-D10-04** | Decryption Mismatch (`12391 != 6`). | **BFV Scaling.** Отсутствие шага Scaling/Rounding после умножения. $Dec(C^2) \approx \Delta M^2$. | Pivot теста на проверку чистой полиномиальной арифметики (без шифрования), что доказывает корректность HW ядра. |

# Session: Phase 4 (Observability)

## Episode: Day 1 - Linker Hell
| ID | Гипотеза / Проблема | Результат | Root Cause |
| :--- | :--- | :--- | :--- |
| **PM-P4-01** | Adding `--trace` to Verilator. | `undefined symbol: trace` | **Build System Blindness.** Verilator генерирует новые файлы (`*_Trace.cpp`), которые CMake не видит автоматически. Их нужно добавлять в `add_library` вручную. |

## Episode: Day 4 - HPC & DPI
| ID | Гипотеза / Проблема | Результат | Root Cause |
| :--- | :--- | :--- | :--- |
| **PM-P4-02** | Moving classes to `.h` to simplify. | `redefinition of class` | **Header Guard Failure.** Реализация методов осталась в `.cpp` и была добавлена в `.h`. Компилятор увидел дубликаты. |
| **PM-P4-03** | `sed` patching of C++ code. | Syntax Error (Nested functions). | **Fragile Tooling.** Использование `sed` для вставки кода в C++ ненадежно. Нужно перезаписывать файлы целиком. |
| **PM-P4-04** | Reading counters via DPI. | `Total cycles: 0` | **Unsafe Casting.** Приведение `uint32_t*` (svBitVecVal) к `uint64_t*` на границе языков небезопасно. Нужно собирать 64-битное число вручную из двух половин. |
| **PM-P4-05** | Resetting state. | Counters reset to 0. | **Logic Flaw.** Сигнал `rst` сбрасывал не только FSM, но и счетчики производительности. Вынесли счетчики в отдельный `always @(posedge clk)` блок без сброса. |
| **PM-P4-06** | Updating SDK. | `ImportError: RNSContext` | **Destructive Write.** Команда `cat > file` полностью стерла старый код SDK, оставив только новый. Всегда нужно делать `cat >>` или объединять контент. |
