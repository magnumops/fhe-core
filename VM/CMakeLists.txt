cmake_minimum_required(VERSION 3.10)
project(logos_vm)

set(CMAKE_CXX_STANDARD 17)

find_package(Python3 COMPONENTS Interpreter Development REQUIRED)
execute_process(
    COMMAND "${Python3_EXECUTABLE}" -m pybind11 --cmakedir
    OUTPUT_VARIABLE pybind11_DIR
    OUTPUT_STRIP_TRAILING_WHITESPACE
)
list(APPEND CMAKE_PREFIX_PATH "${pybind11_DIR}")
find_package(pybind11 REQUIRED)

set(VERILATOR_INCLUDE_DIR "/usr/share/verilator/include")
include_directories(${VERILATOR_INCLUDE_DIR} ${VERILATOR_INCLUDE_DIR}/vltstd)

set(VERILOG_SOURCE "${CMAKE_SOURCE_DIR}/src/rtl/burst_test.v")

add_custom_command(
    OUTPUT Vburst_test.cpp Vburst_test.h Vburst_test__Syms.cpp Vburst_test__Syms.h Vburst_test__Slow.cpp
    COMMAND verilator --cc --exe --Mdir . --CFLAGS "-fPIC" ${VERILOG_SOURCE}
    WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
    DEPENDS ${VERILOG_SOURCE}
    COMMENT "Verilating burst_test.v..."
)

# ИСПРАВЛЕНИЕ ЗДЕСЬ: Добавлен verilated_dpi.cpp
pybind11_add_module(logos_emu
    src/emulator_core.cpp
    src/dpi_impl.cpp
    ${CMAKE_CURRENT_BINARY_DIR}/Vburst_test.cpp
    ${CMAKE_CURRENT_BINARY_DIR}/Vburst_test__Syms.cpp
    ${CMAKE_CURRENT_BINARY_DIR}/Vburst_test__Slow.cpp
    ${VERILATOR_INCLUDE_DIR}/verilated.cpp
    ${VERILATOR_INCLUDE_DIR}/verilated_dpi.cpp 
)

target_include_directories(logos_emu PRIVATE 
    ${CMAKE_CURRENT_BINARY_DIR}
    ${VERILATOR_INCLUDE_DIR}
)
target_compile_options(logos_emu PRIVATE -fPIC)
