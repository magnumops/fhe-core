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
include_directories(${VERILATOR_INCLUDE_DIR} ${VERILATOR_INCLUDE_DIR}/vltstd ${CMAKE_CURRENT_BINARY_DIR})

# --- MAIN TARGET: LOGOS EMULATOR (With NTT Engine) ---
set(RTL_MAIN "${CMAKE_SOURCE_DIR}/src/rtl/ntt/ntt_engine.v")
set(RTL_DEPS 
    "${CMAKE_SOURCE_DIR}/src/rtl/ntt/ntt_control.v"
    "${CMAKE_SOURCE_DIR}/src/rtl/ntt/twiddle_rom.v"
    "${CMAKE_SOURCE_DIR}/src/rtl/ntt/butterfly.v"
    "${CMAKE_SOURCE_DIR}/src/rtl/ntt/mod_add.v"
    "${CMAKE_SOURCE_DIR}/src/rtl/ntt/mod_sub.v"
    "${CMAKE_SOURCE_DIR}/src/rtl/ntt/mod_mult.v"
)

add_custom_command(
    OUTPUT Vntt_engine.cpp Vntt_engine.h Vntt_engine__Syms.cpp Vntt_engine__Syms.h Vntt_engine__Slow.cpp
    COMMAND verilator --cc --exe --Mdir . --CFLAGS "-fPIC" -I${CMAKE_SOURCE_DIR}/src/rtl/ntt ${RTL_MAIN}
    WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
    DEPENDS ${RTL_MAIN} ${RTL_DEPS}
    COMMENT "Verilating ntt_engine (Main Emulator)..."
)

pybind11_add_module(logos_emu
    src/emulator_core.cpp
    src/dpi_impl.cpp
    src/fhe_impl.cpp
    ${CMAKE_CURRENT_BINARY_DIR}/Vntt_engine.cpp
    ${CMAKE_CURRENT_BINARY_DIR}/Vntt_engine__Syms.cpp
    ${CMAKE_CURRENT_BINARY_DIR}/Vntt_engine__Slow.cpp
    ${VERILATOR_INCLUDE_DIR}/verilated.cpp
    ${VERILATOR_INCLUDE_DIR}/verilated_dpi.cpp
)
target_link_libraries(logos_emu PRIVATE SEAL::seal)
