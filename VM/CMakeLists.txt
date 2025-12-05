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
find_package(SEAL REQUIRED)

set(VERILATOR_INCLUDE_DIR "/usr/share/verilator/include")
include_directories(${VERILATOR_INCLUDE_DIR} ${VERILATOR_INCLUDE_DIR}/vltstd ${CMAKE_CURRENT_BINARY_DIR} ${CMAKE_SOURCE_DIR}/src)

# --- MAIN TARGET: LOGOS CORE ---
set(RTL_MAIN "${CMAKE_SOURCE_DIR}/src/rtl/ntt/logos_core.v")
set(RTL_DEPS
    "${CMAKE_SOURCE_DIR}/src/rtl/ntt/command_processor.v"
    "${CMAKE_SOURCE_DIR}/src/rtl/ntt/ntt_engine.v"
    "${CMAKE_SOURCE_DIR}/src/rtl/ntt/ntt_control.v"
    "${CMAKE_SOURCE_DIR}/src/rtl/ntt/twiddle_rom.v"
    "${CMAKE_SOURCE_DIR}/src/rtl/ntt/butterfly.v"
    "${CMAKE_SOURCE_DIR}/src/rtl/ntt/mod_add.v"
    "${CMAKE_SOURCE_DIR}/src/rtl/ntt/mod_sub.v"
    "${CMAKE_SOURCE_DIR}/src/rtl/ntt/mod_mult.v"
)

# ВАЖНО: Добавлены Vlogos_core__Trace*.cpp в OUTPUT
add_custom_command(
    OUTPUT Vlogos_core.cpp Vlogos_core.h Vlogos_core__Syms.cpp Vlogos_core__Syms.h Vlogos_core__Slow.cpp Vlogos_core__Trace.cpp Vlogos_core__Trace__Slow.cpp
    COMMAND verilator --cc --exe --Mdir . --CFLAGS "-fPIC" --output-split 0 --output-split-cfuncs 0 --trace -I${CMAKE_SOURCE_DIR}/src/rtl/ntt ${RTL_MAIN}
    WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
    DEPENDS ${RTL_MAIN} ${RTL_DEPS}
    COMMENT "Verilating logos_core (With Trace)..."
)

# ВАЖНО: Добавлены файлы трассировки и verilated_vcd_c.cpp в список исходников
pybind11_add_module(logos_emu
    src/emulator_core.cpp
    src/dpi_impl.cpp
    src/fhe_impl.cpp
    ${CMAKE_CURRENT_BINARY_DIR}/Vlogos_core.cpp
    ${CMAKE_CURRENT_BINARY_DIR}/Vlogos_core__Syms.cpp
    ${CMAKE_CURRENT_BINARY_DIR}/Vlogos_core__Slow.cpp
    ${CMAKE_CURRENT_BINARY_DIR}/Vlogos_core__Trace.cpp
    ${CMAKE_CURRENT_BINARY_DIR}/Vlogos_core__Trace__Slow.cpp
    ${VERILATOR_INCLUDE_DIR}/verilated.cpp
    ${VERILATOR_INCLUDE_DIR}/verilated_dpi.cpp
    ${VERILATOR_INCLUDE_DIR}/verilated_vcd_c.cpp
)
target_link_libraries(logos_emu PRIVATE SEAL::seal)

# --- OLD TARGETS (Minimal support) ---
# ALU Tester (No Trace needed for now, keep as is or minimal)
set(RTL_ALU "${CMAKE_SOURCE_DIR}/src/rtl/ntt/vec_alu.v")
add_custom_command(
    OUTPUT Vvec_alu.cpp Vvec_alu.h Vvec_alu__Syms.cpp Vvec_alu__Syms.h Vvec_alu__Slow.cpp
    COMMAND verilator --cc --exe --Mdir . --CFLAGS "-fPIC" -I${CMAKE_SOURCE_DIR}/src/rtl/ntt ${RTL_ALU}
    WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
    DEPENDS ${RTL_ALU}
    COMMENT "Verilating vec_alu..."
)
pybind11_add_module(alu_tester
    src/alu_tester.cpp
    ${CMAKE_CURRENT_BINARY_DIR}/Vvec_alu.cpp
    ${CMAKE_CURRENT_BINARY_DIR}/Vvec_alu__Syms.cpp
    ${CMAKE_CURRENT_BINARY_DIR}/Vvec_alu__Slow.cpp
    ${VERILATOR_INCLUDE_DIR}/verilated.cpp
)

pybind11_add_module(logos_fhe src/main.cpp src/fhe_impl.cpp)
target_link_libraries(logos_fhe PRIVATE SEAL::seal)
