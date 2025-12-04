cmake_minimum_required(VERSION 3.10)
project(logos_vm)

set(CMAKE_CXX_STANDARD 17)

# --- Python & PyBind11 ---
find_package(Python3 COMPONENTS Interpreter Development REQUIRED)
execute_process(
    COMMAND "${Python3_EXECUTABLE}" -m pybind11 --cmakedir
    OUTPUT_VARIABLE pybind11_DIR
    OUTPUT_STRIP_TRAILING_WHITESPACE
)
list(APPEND CMAKE_PREFIX_PATH "${pybind11_DIR}")
find_package(pybind11 REQUIRED)

# --- Verilator Setup ---
set(VERILATOR_INCLUDE_DIR "/usr/share/verilator/include")
include_directories(${VERILATOR_INCLUDE_DIR} ${VERILATOR_INCLUDE_DIR}/vltstd)

set(VERILOG_SOURCE "${CMAKE_SOURCE_DIR}/src/rtl/counter.v")

# Генерация C++ из Verilog
add_custom_command(
    OUTPUT 
        Vcounter.cpp Vcounter.h 
        Vcounter__Syms.cpp Vcounter__Syms.h
        Vcounter__Slow.cpp
    COMMAND verilator --cc --exe --Mdir . --CFLAGS "-fPIC" ${VERILOG_SOURCE}
    WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
    DEPENDS ${VERILOG_SOURCE}
    COMMENT "Verilating counter.v..."
)

# --- The Great Merger: Собираем все в один Python модуль ---
# pybind11_add_module автоматически делает библиотеку .so
pybind11_add_module(logos_emu
    src/emulator_core.cpp
    ${CMAKE_CURRENT_BINARY_DIR}/Vcounter.cpp
    ${CMAKE_CURRENT_BINARY_DIR}/Vcounter__Syms.cpp
    ${CMAKE_CURRENT_BINARY_DIR}/Vcounter__Slow.cpp
    ${VERILATOR_INCLUDE_DIR}/verilated.cpp
)

# Указываем, где искать заголовки (generated + verilator)
target_include_directories(logos_emu PRIVATE 
    ${CMAKE_CURRENT_BINARY_DIR}
    ${VERILATOR_INCLUDE_DIR}
)

# Важно: Verilator код должен быть собран с -fPIC, так как это shared library
target_compile_options(logos_emu PRIVATE -fPIC)
