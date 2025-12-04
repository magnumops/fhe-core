
## Episode: Day 5 - Multi-Bank Memory & Timeout Debugging
| ID | Симптом | Root Cause | Fix |
| :--- | :--- | :--- | :--- |
| **PM-P3-06** | `pathspec did not match` | **Navigation Error.** Запуск git команд с путями подпапки из корня. | Использовать полные пути или `cd`. |
| **PM-P3-07** | `Warning-WIDTH` | **Type Mismatch.** Индексация массива `mem[4]` 3-битным регистром. | Явное усечение `current_slot[1:0]`. |
| **PM-P3-09** | `undefined symbol ..._eval` | **Verilator Split.** Большой RTL разбился на файлы, не включенные в CMake. | Флаг `--output-split 0`. |
| **PM-P3-12** | `undefined symbol: sc_time_stamp` | **Missing Hook.** Verilator требует функцию времени. | Добавлена `double sc_time_stamp() { return 0; }` в C++. |
| **PM-P3-13** | Runtime Timeout (No Logs) | **Log Flooding.** Слишком частый вывод `$display` забил буфер Docker. | Логирование перенесено в C++ и ограничено (heartbeat). |
| **PM-P3-14** | Stack Smashing | **ABI Mismatch.** C++ ожидал указатель, Verilog передавал Open Array Handle. | Восстановлена сигнатура `svOpenArrayHandle` в C++. |
