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
