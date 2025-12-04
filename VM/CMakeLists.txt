cmake_minimum_required(VERSION 3.10)
project(logos_vm)

set(CMAKE_CXX_STANDARD 17)

# Python & Pybind11
find_package(Python3 COMPONENTS Interpreter Development REQUIRED)
execute_process(
    COMMAND "${Python3_EXECUTABLE}" -m pybind11 --cmakedir
    OUTPUT_VARIABLE pybind11_DIR
    OUTPUT_STRIP_TRAILING_WHITESPACE
)
list(APPEND CMAKE_PREFIX_PATH "${pybind11_DIR}")
find_package(pybind11 REQUIRED)
find_package(SEAL REQUIRED)

# Verilator Setup
set(VERILATOR_INCLUDE_DIR "/usr/share/verilator/include")
# Включаем BINARY_DIR для поиска V*.h файлов
include_directories(${VERILATOR_INCLUDE_DIR} ${VERILATOR_INCLUDE_DIR}/vltstd ${CMAKE_CURRENT_BINARY_DIR})

# --- TARGET 1: MAIN EMULATOR (Legacy/MVP) ---
set(RTL_MAIN "${CMAKE_SOURCE_DIR}/src/rtl/copy_engine.v")
add_custom_command(
    OUTPUT Vcopy_engine.cpp Vcopy_engine.h Vcopy_engine__Syms.cpp Vcopy_engine__Syms.h Vcopy_engine__Slow.cpp
    COMMAND verilator --cc --exe --Mdir . --CFLAGS "-fPIC" ${RTL_MAIN}
    WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
    DEPENDS ${RTL_MAIN}
    COMMENT "Verilating copy_engine.v..."
)
pybind11_add_module(logos_emu
    src/emulator_core.cpp
    src/dpi_impl.cpp
    src/fhe_impl.cpp
    ${CMAKE_CURRENT_BINARY_DIR}/Vcopy_engine.cpp
    ${CMAKE_CURRENT_BINARY_DIR}/Vcopy_engine__Syms.cpp
    ${CMAKE_CURRENT_BINARY_DIR}/Vcopy_engine__Slow.cpp
    ${VERILATOR_INCLUDE_DIR}/verilated.cpp
    ${VERILATOR_INCLUDE_DIR}/verilated_dpi.cpp  # <--- FIX: Vital for Open Arrays!
)
target_link_libraries(logos_emu PRIVATE SEAL::seal)

# --- TARGET 2: NTT UNIT TESTER (New Day 2) ---
set(RTL_NTT "${CMAKE_SOURCE_DIR}/src/rtl/ntt/ntt_arith_unit.v")
add_custom_command(
    OUTPUT Vntt_arith_unit.cpp Vntt_arith_unit.h Vntt_arith_unit__Syms.cpp Vntt_arith_unit__Syms.h Vntt_arith_unit__Slow.cpp
    COMMAND verilator --cc --exe --Mdir . --CFLAGS "-fPIC" -I${CMAKE_SOURCE_DIR}/src/rtl/ntt ${RTL_NTT}
    WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
    DEPENDS ${RTL_NTT} "${CMAKE_SOURCE_DIR}/src/rtl/ntt/mod_add.v" "${CMAKE_SOURCE_DIR}/src/rtl/ntt/mod_mult.v"
    COMMENT "Verilating ntt_arith_unit.v..."
)

pybind11_add_module(ntt_tester
    src/ntt_test_core.cpp
    ${CMAKE_CURRENT_BINARY_DIR}/Vntt_arith_unit.cpp
    ${CMAKE_CURRENT_BINARY_DIR}/Vntt_arith_unit__Syms.cpp
    ${CMAKE_CURRENT_BINARY_DIR}/Vntt_arith_unit__Slow.cpp
    ${VERILATOR_INCLUDE_DIR}/verilated.cpp
    ${VERILATOR_INCLUDE_DIR}/verilated_dpi.cpp  # <--- FIX: Good practice to add here too
)
