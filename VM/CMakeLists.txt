cmake_minimum_required(VERSION 3.10)
project(logos_vm)
set(CMAKE_CXX_STANDARD 17)

find_package(Python3 COMPONENTS Interpreter Development REQUIRED)
execute_process(COMMAND "${Python3_EXECUTABLE}" -m pybind11 --cmakedir OUTPUT_VARIABLE pybind11_DIR OUTPUT_STRIP_TRAILING_WHITESPACE)
list(APPEND CMAKE_PREFIX_PATH "${pybind11_DIR}")
find_package(pybind11 REQUIRED)
find_package(SEAL REQUIRED)

set(VERILATOR_INCLUDE_DIR "/usr/share/verilator/include")
include_directories(${VERILATOR_INCLUDE_DIR} ${VERILATOR_INCLUDE_DIR}/vltstd)

set(VERILOG_TOP "${CMAKE_SOURCE_DIR}/src/rtl/logos_core.v")
set(RTL_SOURCES 
    ${VERILOG_TOP}
    "${CMAKE_SOURCE_DIR}/src/rtl/ntt/hazard_unit.v"
    "${CMAKE_SOURCE_DIR}/src/rtl/ntt/ntt_core.v"
    "${CMAKE_SOURCE_DIR}/src/rtl/command_processor.v"
    "${CMAKE_SOURCE_DIR}/src/rtl/mem_arbiter.v"
    "${CMAKE_SOURCE_DIR}/src/rtl/dpi_mem_wrapper.v"
    "${CMAKE_SOURCE_DIR}/src/rtl/dma_unit.v"
)

add_custom_command(
    OUTPUT Vlogos_core.cpp Vlogos_core.h Vlogos_core__Syms.cpp Vlogos_core__Syms.h Vlogos_core__Slow.cpp
    COMMAND verilator --cc --exe --Mdir . --CFLAGS "-fPIC" -Wno-fatal --top-module logos_core ${RTL_SOURCES}
    WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
    DEPENDS ${RTL_SOURCES}
    COMMENT "Verilating logos_core..."
)

pybind11_add_module(logos_emu
    src/emulator_core.cpp
    src/dpi_impl.cpp
    ${CMAKE_CURRENT_BINARY_DIR}/Vlogos_core.cpp
    ${CMAKE_CURRENT_BINARY_DIR}/Vlogos_core__Syms.cpp
    ${CMAKE_CURRENT_BINARY_DIR}/Vlogos_core__Slow.cpp
    ${VERILATOR_INCLUDE_DIR}/verilated.cpp
    ${VERILATOR_INCLUDE_DIR}/verilated_dpi.cpp 
)

target_include_directories(logos_emu PRIVATE ${CMAKE_CURRENT_BINARY_DIR} ${VERILATOR_INCLUDE_DIR})
target_compile_options(logos_emu PRIVATE -fPIC)
