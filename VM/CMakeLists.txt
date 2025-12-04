cmake_minimum_required(VERSION 3.10)
project(logos_vm)

set(CMAKE_CXX_STANDARD 17)

# --- ЧАСТЬ 1: PyBind11 ---
find_package(Python3 COMPONENTS Interpreter Development REQUIRED)
execute_process(
    COMMAND "${Python3_EXECUTABLE}" -m pybind11 --cmakedir
    OUTPUT_VARIABLE pybind11_DIR
    OUTPUT_STRIP_TRAILING_WHITESPACE
)
list(APPEND CMAKE_PREFIX_PATH "${pybind11_DIR}")
find_package(pybind11 REQUIRED)

pybind11_add_module(spike_pybind src/spike_pybind.cpp)

# --- ЧАСТЬ 2: Verilator ---
set(VERILATOR_INCLUDE_DIR "/usr/share/verilator/include")
message(STATUS "Using Verilator include dir: ${VERILATOR_INCLUDE_DIR}")

include_directories(${VERILATOR_INCLUDE_DIR} ${VERILATOR_INCLUDE_DIR}/vltstd)

set(VERILOG_SOURCE "${CMAKE_SOURCE_DIR}/src/rtl/counter.v")

# ИСПРАВЛЕНИЕ ЗДЕСЬ:
# Мы перечисляем ВСЕ файлы, которые создаст Verilator, в секции OUTPUT.
# Это говорит CMake'у: "Не ищи эти файлы на диске сразу, они появятся после выполнения команды".
add_custom_command(
    OUTPUT 
        Vcounter.cpp 
        Vcounter.h 
        Vcounter__Syms.cpp 
        Vcounter__Syms.h
        Vcounter__Slow.cpp
    COMMAND verilator --cc --exe --Mdir . ${VERILOG_SOURCE}
    WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
    DEPENDS ${VERILOG_SOURCE}
    COMMENT "Verilating counter.v..."
)

# Теперь добавляем эти же файлы в сборку
add_executable(verilator_test 
    src/sim_main_day3.cpp
    ${CMAKE_CURRENT_BINARY_DIR}/Vcounter.cpp 
    ${CMAKE_CURRENT_BINARY_DIR}/Vcounter__Syms.cpp
    ${CMAKE_CURRENT_BINARY_DIR}/Vcounter__Slow.cpp
    ${VERILATOR_INCLUDE_DIR}/verilated.cpp
)

include_directories(${CMAKE_CURRENT_BINARY_DIR})
