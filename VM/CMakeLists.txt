cmake_minimum_required(VERSION 3.10)
project(LOGOS_FHE_VM)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -O3 -fPIC")

# --- 1. Python & Pybind11 ---
find_package(Python3 COMPONENTS Interpreter Development REQUIRED)
execute_process(
    COMMAND "${Python3_EXECUTABLE}" -m pybind11 --cmakedir
    OUTPUT_VARIABLE PYBIND11_CMAKE_DIR
    OUTPUT_STRIP_TRAILING_WHITESPACE
)
list(APPEND CMAKE_PREFIX_PATH "${PYBIND11_CMAKE_DIR}")
find_package(pybind11 REQUIRED)

# --- 2. Verilator Setup ---
find_program(VERILATOR_BIN verilator REQUIRED)
execute_process(
    COMMAND ${VERILATOR_BIN} --getenv VERILATOR_ROOT
    OUTPUT_VARIABLE VERILATOR_ROOT
    OUTPUT_STRIP_TRAILING_WHITESPACE
)
set(VERILATOR_INC_DIR "${VERILATOR_ROOT}/include")
set(VERILATOR_VLTSTD_DIR "${VERILATOR_ROOT}/include/vltstd")

# --- 3. Run Verilator NOW (Configure Time) ---
# Это гарантирует, что мы знаем точный список файлов до начала сборки
set(VERILATOR_SRC 
    ${CMAKE_CURRENT_SOURCE_DIR}/src/rtl/logos_core.v 
    ${CMAKE_CURRENT_SOURCE_DIR}/src/rtl/mem_arbiter.v 
    ${CMAKE_CURRENT_SOURCE_DIR}/src/rtl/ntt/ntt_engine.v
)
set(V_OUT_DIR "${CMAKE_CURRENT_BINARY_DIR}/verilator_out")
file(MAKE_DIRECTORY ${V_OUT_DIR})

message(STATUS "Running Verilator to generate source files...")
execute_process(
    COMMAND ${VERILATOR_BIN} --cc --exe --Mdir "${V_OUT_DIR}"
            --CFLAGS "-fPIC -O3"
            -Wno-fatal -Wno-WIDTH 
            --top-module logos_core
            ${VERILATOR_SRC}
    RESULT_VARIABLE V_RES
)
if(NOT V_RES EQUAL 0)
    message(FATAL_ERROR "Verilator failed to generate C++ model")
endif()

# --- 4. Collect ALL Generated Sources ---
# Находим ВСЕ .cpp файлы, которые создал Verilator
file(GLOB V_ALL_GENERATED_SRCS "${V_OUT_DIR}/*.cpp")

# --- 5. Build Python Module ---
include_directories(${V_OUT_DIR})
add_definitions(-DVL_PRINTF=printf)

pybind11_add_module(logos_emu 
    src/emulator_core.cpp
    ${V_ALL_GENERATED_SRCS} # Включаем всё, что нашли
    ${VERILATOR_INC_DIR}/verilated.cpp
    ${VERILATOR_INC_DIR}/verilated_vcd_c.cpp
    ${VERILATOR_INC_DIR}/verilated_threads.cpp
)

target_include_directories(logos_emu PUBLIC 
    ${VERILATOR_INC_DIR}
    ${VERILATOR_VLTSTD_DIR}
    ${V_OUT_DIR}
)
