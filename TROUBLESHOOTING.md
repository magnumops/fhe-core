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
