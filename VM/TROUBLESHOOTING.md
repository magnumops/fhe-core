
## Verilator: Stack Smashing (DPI)
**Симптом:** `stack smashing detected` при вызове импортированной функции.
**Причина:** Несовпадение типов аргументов. Verilog `output bit []` требует C++ `const svOpenArrayHandle`.
**Решение:** Использовать `svGetArrElemPtr1` для доступа к данным массива внутри C++.

## Verilator: Linker Error `sc_time_stamp`
**Симптом:** `undefined reference to sc_time_stamp`.
**Решение:** Определить фиктивную функцию в C++ коде: `double sc_time_stamp() { return 0; }`.

## RNS Math Mismatch
**Симптом:** RNS арифметика работает для первого модуля, но выдает мусор для второго.
**Причина:** Использование статических (Pre-computed) констант в железе (Twiddle Factors), которые зависят от модуля $Q$.
**Решение:** Сделать память констант перезаписываемой (RAM) и загружать правильную таблицу при переключении контекста (Context Switching).

## SEAL Context: RNS Mismatch
**Симптом:** `RNS index out of bounds` при доступе к полиномам SEAL.
**Причина:** SEAL BFV требует "Special Prime" для Key Switching. Если вы передали $N$ модулей, данных будет $N-1$.
**Решение:** При инициализации SEAL передавать на один модуль больше, чем нужно для данных.

## Hardware Memory Management (OOM)
**Симптом:** `Out of Device Memory` в сложном вычислении.
**Причина:** Ограниченное количество слотов (4). Один RNS вектор занимает $K$ слотов.
**Решение:** Разбивать сложные формулы (например, $A \cdot B + C \cdot D$) на части, выгружая промежуточные результаты на хост.
