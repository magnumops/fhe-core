# Реестр Успешных Решений (TROUBLESHOOTING)

## Verilator + CMake + Docker (Ubuntu 22.04)
**Проблема:** Сложность правильной сборки Verilator-модели внутри CMake проекта.
**Решение (Golden Pattern):**

1.  **Хардкод путей:** В Ubuntu 22.04 путь к хедерам всегда `/usr/share/verilator/include`.
2.  **Абсолютные пути к RTL:** Использовать `${CMAKE_SOURCE_DIR}/src/...` для `.v` файлов.
3.  **Полный список OUTPUT:** В команде `add_custom_command` перечислять ВСЕ генерируемые файлы:
    *   `Vmodel.cpp`
    *   `Vmodel.h`
    *   `Vmodel__Syms.cpp`
    *   `Vmodel__Syms.h`
    *   `Vmodel__Slow.cpp` (Критично для конструкторов!)
4.  **Зависимость:** Дублировать этот же список в `add_executable`.

**Пример (CMakeLists.txt snippet):**
```cmake
set(VERILATOR_INCLUDE_DIR "/usr/share/verilator/include")
set(RTL_SRC "${CMAKE_SOURCE_DIR}/src/rtl/counter.v")

add_custom_command(
    OUTPUT Vcounter.cpp Vcounter.h Vcounter__Syms.cpp Vcounter__Slow.cpp
    COMMAND verilator --cc --exe --Mdir . ${RTL_SRC}
    ...
)
add_executable(test_sim ... Vcounter.cpp Vcounter__Syms.cpp Vcounter__Slow.cpp ...)

## PyBind11 + Verilator (Shared Library)
**Проблема:** Как собрать Verilator-модель не в `.exe`, а в `.so` модуль для Python?
**Решение:**
1.  Использовать `pybind11_add_module`.
2.  Скармливать ему **напрямую** сгенерированные `.cpp` файлы Verilator (`Vcounter.cpp` и т.д.).
3.  **КРИТИЧНО:** Добавить флаг `-fPIC` при генерации кода Verilator (`--CFLAGS "-fPIC"`). Без этого линковщик откажется собирать разделяемую библиотеку (shared object).
4.  В Python добавлять путь к `.so` через `sys.path.append`.

## Эмуляция RAM > Физического Диска (Sparse Files)
**Проблема:** Как эмулировать 1 ТБ памяти для FHE на сервере с диском 50 ГБ?
**Решение:**
Использовать механизм "Разреженных файлов" (Sparse Files) в Linux.
1. `open("file", O_CREAT ...)`
2. `ftruncate(fd, 1TB)` — это мгновенно резервирует *адресное пространство*, но не блоки на диске. Файл весит 0 байт.
3. `mmap(...)` — отображает это в память.
4. Linux выделяет реальные блоки на SSD (4KB pages) только при *записи* по конкретному адресу.
**Результат:** Можно симулировать огромную память, потребляя диск только под реальные данные.

## Verilog DPI + C++ Classes
**Проблема:** DPI-функции в C++ (`extern "C"`) ничего не знают про классы и объекты. Как из `dpi_read_ram` получить доступ к объекту `VirtualRAM`?
**Решение:**
Использовать паттерн **Singleton** (Глобальный указатель).
1. В C++ создать глобальную переменную `VirtualRAM* g_ram = nullptr;`.
2. В конструкторе симулятора делать `g_ram = new VirtualRAM()`.
3. В DPI-функции проверять `if (g_ram) return g_ram->read(...)`.
**Важно:** Инициализировать память строго ДО того, как Verilog попытается к ней обратиться (в конструкторе Wrapper-класса).

## Python Import в Docker
**Проблема:** `ModuleNotFoundError` при запуске тестов внутри Docker.
**Решение:**
Явно добавлять путь к папке сборки: `sys.path.append("/app/build")`.

## Verilog DPI Open Arrays
**Проблема 1:** `undefined symbol: svGetArrElemPtr1` при линковке.
**Решение:** Если вы используете функции работы с массивами DPI (Open Arrays), необходимо добавить файл `${VERILATOR_INCLUDE_DIR}/verilated_dpi.cpp` в список исходников CMake.

**Проблема 2:** Мусорные данные при чтении массива в C++.
**Причина:** Использование типа `reg` (4-state logic) в Verilog. Verilator представляет `reg` как сложную структуру, а не как чистое число.
**Решение:** В интерфейсе DPI всегда использовать тип **`bit`** (2-state logic). Он бинарно совместим с C++ типами (`uint64_t`).

## Microsoft SEAL Integration
**Проблема:** Сборка SEAL занимает слишком много времени или падает по памяти.
**Решение:**
1. Отключить необязательные зависимости: `-DSEAL_USE_MSGSL=OFF -DSEAL_USE_ZLIB=OFF`.
2. Использовать релизную ветку (например, `v4.1.1`), а не main.
3. Кешировать слой сборки в Docker (делать установку SEAL отдельным слоем `RUN`).

## C++ PyBind Dependencies
**Проблема:** `error: 'pybind11' does not name a type`.
**Решение:** Всегда включать `#include <pybind11/pybind11.h>` в C++ файл, если в нем используются типы PyBind, даже если это вспомогательный файл реализации.

## Python Import Order
**Проблема:** `ModuleNotFoundError` даже при наличии `sys.path.append`.
**Решение:** Команда `sys.path.append(...)` должна выполняться СТРОГО ПЕРЕД командой `import logos_emu`.

## FHE Параметры (SEAL BFV)
**Проблема:** `ValueError: plain is not valid for encryption parameters`.
**Причина:** Пытаетесь зашифровать число, которое больше `plain_modulus`.
**Решение:** Увеличить `plain_modulus` (например, до 65537 для 16-битных чисел).

## Verilog Buffers & Ciphertext Size
**Проблема:** Ошибка декомпрессии SEAL (`stream decompression failed`) после обработки данных в Verilog.
**Причина:** Размер шифртекста FHE огромен (сотни килобайт). Если внутренний буфер Verilog-модуля меньше шифртекста, хвост данных теряется.
**Решение:** Всегда рассчитывать размер буферов исходя из параметров криптосистемы (PolyDegree * CoeffModulusSize). Для Degree=4096 буфер должен быть > 100 КБ.

## Verilator Generated Headers Not Found
**Проблема:** Ошибка `fatal error: Vmodel.h: No such file or directory` при компиляции C++ обертки.
**Причина:** Verilator генерирует файлы внутри папки сборки (`build` или `${CMAKE_CURRENT_BINARY_DIR}`), но C++ компилятор не ищет там заголовочные файлы по умолчанию.
**Решение:**
Добавить в `CMakeLists.txt` строку:
\`\`\`cmake
include_directories(\${CMAKE_CURRENT_BINARY_DIR})
\`\`\`

## Verilator Lint: WIDTH Warnings (Strict Mode)
**Проблема:** Ошибка сборки `Operator ASSIGNW expects X bits ... but ... generates Y bits`.
**Причина:** Verilator требует явного приведения типов при любом несовпадении разрядности.
**Решение (Explicit Casting):**
1. **Расширение (Padding):** `{1'b0, variable}` или `{64'b0, variable}`.
2. **Сужение (Truncation):** `variable[63:0]`.
*Пример:*
\`\`\`verilog
wire [127:0] prod = {64'b0, a} * {64'b0, b}; // Явное расширение входов
assign out = prod[63:0];                     // Явное сужение выхода
\`\`\`

## Linker Error: svGetArrElemPtr1
**Проблема:** `undefined symbol: svGetArrElemPtr1` при импорте модуля в Python.
**Причина:** В сборке отсутствует реализация функций DPI Open Arrays, необходимая для `verilated` библиотеки.
**Решение:**
Всегда добавлять `\${VERILATOR_INCLUDE_DIR}/verilated_dpi.cpp` в список исходных файлов `pybind11_add_module`, если проект использует DPI.

## Verilator Generated Headers Not Found
**Проблема:** Ошибка `fatal error: Vmodel.h: No such file or directory` при компиляции C++ обертки.
**Причина:** Verilator генерирует файлы внутри папки сборки (`build` или `${CMAKE_CURRENT_BINARY_DIR}`), но C++ компилятор не ищет там заголовочные файлы по умолчанию.
**Решение:**
Добавить в `CMakeLists.txt` строку:
\`\`\`cmake
include_directories(\${CMAKE_CURRENT_BINARY_DIR})
\`\`\`

## Verilator Lint: WIDTH Warnings (Strict Mode)
**Проблема:** Ошибка сборки `Operator ASSIGNW expects X bits ... but ... generates Y bits`.
**Причина:** Verilator требует явного приведения типов при любом несовпадении разрядности.
**Решение (Explicit Casting):**
1. **Расширение (Padding):** `{1'b0, variable}` или `{64'b0, variable}`.
2. **Сужение (Truncation):** `variable[63:0]`.
*Пример:*
\`\`\`verilog
wire [127:0] prod = {64'b0, a} * {64'b0, b}; // Явное расширение входов
assign out = prod[63:0];                     // Явное сужение выхода
\`\`\`

## Linker Error: svGetArrElemPtr1
**Проблема:** `undefined symbol: svGetArrElemPtr1` при импорте модуля в Python.
**Причина:** В сборке отсутствует реализация функций DPI Open Arrays, необходимая для `verilated` библиотеки.
**Решение:**
Всегда добавлять `\${VERILATOR_INCLUDE_DIR}/verilated_dpi.cpp` в список исходных файлов `pybind11_add_module`, если проект использует DPI.

## Verilator API Versioning
**Проблема:** Ошибки компиляции C++ обертки, связанные с `VerilatedContext` или `Verilated::traceEverOn`.
**Причина:** Различие версий Verilator. В Ubuntu LTS часто лежат старые версии (4.0xx), не поддерживающие Modern API (4.2xx+).
**Решение:**
Использовать Legacy API для инстанцирования моделей:
\`\`\`cpp
// Вместо Modern API
// const std::unique_ptr<VerilatedContext> contextp{new VerilatedContext};
// const std::unique_ptr<Vmodel> top{new Vmodel{contextp.get()}};

// Использовать Legacy (Raw Pointers)
Vmodel* top = new Vmodel;
top->eval();
delete top;
\`\`\`

## Verilog Last Cycle Validity
**Проблема:** Потеря данных на последнем такте работы конвейера.
**Причина:** Сброс сигнала `valid` в том же такте, когда вычисляются последние данные, но происходит переход состояния в `DONE`.
**Решение:**
Не сбрасывать `valid` внутри логики перехода. Позволить ему оставаться `1` на последнем такте. Сбрасывать его только после входа в состояние `DONE`.

## NTT Algorithm Mismatch (Standard vs Negacyclic, DIT vs DIF)
**Проблема:** Аппаратный NTT выдает "мусор" при сравнении с наивной реализацией DFT/NTT.
**Причина:**
1. Алгоритм Cooley-Tukey DIT (Decimation-in-Time) математически требует, чтобы входные данные были переставлены в **Bit-Reversed** порядке.
2. Аппаратная реализация вычисляет **Standard (Cyclic) NTT**. Если криптосистема требует **Negacyclic NTT** (как BFV), необходимо домножать входные данные на $\psi^i$ перед подачей в NTT (или использовать другой набор твиддлов).
**Решение:**
Перед загрузкой данных в DIT-ускоритель обязательно выполнять программную перестановку битов (Bit-Reversal Permutation).

## Missing C++ Headers (Standard Library)
**Проблема:** Ошибки вида `size_t has not been declared` или `std::vector` not found.
**Причина:** Современные компиляторы (GCC 11+) требуют явного подключения заголовков.
**Решение:**
Всегда подключать:
* `<cstddef>` для `size_t`.
* `<cstdint>` для `uint64_t`.
* `<vector>` для `std::vector`.
* `<pybind11/stl.h>` для автоматической конвертации Python list <-> std::vector.

## Verilog vs DPI Type Mismatch (reg vs bit)
**Проблема:** При передаче массива из C++ в Verilog через DPI Open Array (`output bit [63:0] data []`), данные не загружаются (остаются нулями), если Verilog-массив объявлен как `reg`.
**Причина:** `reg` в SystemVerilog — это 4-state logic (0, 1, X, Z). C++ типы (`svBitVecVal`) — это 2-state logic. Функция `svGetArrElemPtr` для `reg` возвращает сложную структуру `svLogicVecVal`, несовместимую с простой записью битов.
**Решение:**
При использовании DPI Open Arrays для передачи данных, Verilog-массив должен быть объявлен как **`bit`** (2-state logic).
\`\`\`verilog
// Правильно:
bit [63:0] mem [0:N-1]; 
// Неправильно:
// reg [63:0] mem [0:N-1];
\`\`\`

## Verilator: Stack Smashing in DPI
**Проблема:** `stack smashing detected` при вызове DPI функции.
**Причина:** Несоответствие сигнатур. Если в Verilog используется Open Array (`output bit [63:0] data []`), то в C++ функция **обязана** принимать `const svOpenArrayHandle`.
**Решение:**
1. Использовать `svOpenArrayHandle` в аргументах C++.
2. Использовать `svGetArrElemPtr1(h, i)` для доступа к данным.
3. Либо отказаться от Open Arrays в Verilog и передавать простой указатель (но тогда теряется информация о длине).

## Verilator: Undefined Symbol `_eval` (Split Files)
**Проблема:** Ошибка линковки при большом размере RTL (например, большая память).
**Причина:** Verilator по умолчанию разбивает выходной C++ код на несколько файлов (`Vmodel__1.cpp` и т.д.), если код слишком большой. CMakeLists, настроенный вручную, не знает об этих файлах.
**Решение:**
Добавить флаги `--output-split 0 --output-split-cfuncs 0` в команду verilator. Это заставит его генерировать всё в одном файле `Vmodel.cpp`.

## Verilator: Undefined Symbol `sc_time_stamp`
**Проблема:** Ошибка линковки при использовании `$time` в Verilog.
**Причина:** Verilator требует, чтобы хост-система предоставляла текущее время симуляции.
**Решение:** Добавить в C++ код (глобально):
```cpp
double sc_time_stamp() { return 0; }
```

## Verilator: WIDTH Warnings (Strict)
**Проблема:** `Warning-WIDTH: Bit extraction of array[3:0] requires 2 bit index`.
**Причина:** Попытка индексировать массив размером $2^N$ переменной размером $M > N$ бит.
**Решение:** Явно приводить индекс к нужной ширине: `mem[idx[1:0]]`.

## Docker & Python Caching
**Проблема:** Python в Docker не видит изменений в `.py` файлах (например, новых переменных конфига).
**Причина:** `COPY . /app` копирует папку `__pycache__` с хоста. Python загружает старый байт-код.
**Решение:**
1. Добавить `__pycache__` и `*.pyc` в `.dockerignore`.
2. Удалять `__pycache__` перед сборкой.

## Verilator: Stack Smashing in DPI
**Проблема:** `stack smashing detected` при вызове DPI функции.
**Причина:** Несоответствие сигнатур. Если в Verilog используется Open Array (`output bit [63:0] data []`), то в C++ функция **обязана** принимать `const svOpenArrayHandle`.
**Решение:**
1. Использовать `svOpenArrayHandle` в аргументах C++.
2. Использовать `svGetArrElemPtr1(h, i)` для доступа к данным.
3. Либо отказаться от Open Arrays в Verilog и передавать простой указатель (но тогда теряется информация о длине).

## Verilator: Undefined Symbol `_eval` (Split Files)
**Проблема:** Ошибка линковки при большом размере RTL (например, большая память).
**Причина:** Verilator по умолчанию разбивает выходной C++ код на несколько файлов (`Vmodel__1.cpp` и т.д.), если код слишком большой. CMakeLists, настроенный вручную, не знает об этих файлах.
**Решение:**
Добавить флаги `--output-split 0 --output-split-cfuncs 0` в команду verilator. Это заставит его генерировать всё в одном файле `Vmodel.cpp`.

## Verilator: Undefined Symbol `sc_time_stamp`
**Проблема:** Ошибка линковки при использовании `$time` в Verilog.
**Причина:** Verilator требует, чтобы хост-система предоставляла текущее время симуляции.
**Решение:** Добавить в C++ код (глобально):
```cpp
double sc_time_stamp() { return 0; }


Verilator: WIDTH Warnings (Strict)
Проблема: Warning-WIDTH: Bit extraction of array[3:0] requires 2 bit index.
Причина: Попытка индексировать массив размером $2^N$ переменной размером $M > N$ бит.
Решение: Явно приводить индекс к нужной ширине: mem[idx[1:0]].
Docker & Python Caching
Проблема: Python в Docker не видит изменений в .py файлах (например, новых переменных конфига).
Причина: COPY . /app копирует папку __pycache__ с хоста. Python загружает старый байт-код.
Решение:
Добавить __pycache__ и *.pyc в .dockerignore.
Удалять __pycache__ перед сборкой.

## Verilator & DPI Headers
**Проблема:** `error: 'svOpenArrayHandle' does not name a type`.
**Решение:** В любом C++ файле, использующем типы DPI, обязан быть `#include "svdpi.h"`.

## PyBind11 Arguments
**Проблема:** `TypeError: incompatible function arguments` при вызове с именованными аргументами (`func(a=1)`).
**Решение:** По умолчанию PyBind экспортирует функции только с позиционными аргументами. Либо использовать `func(1)`, либо явно прописывать `py::arg("a")` в C++ дефиниции.

## Verilog Command Interfaces
**Проблема:** Потеря команд при быстрой отправке из C++.
**Решение:** Всегда реализовывать механизм Ready/Valid (Handshake). C++ драйвер обязан ждать `top->cmd_ready == 1` перед снятием `cmd_valid`.
