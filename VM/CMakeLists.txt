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

set(VERILATOR_OUT_DIR "${CMAKE_CURRENT_SOURCE_DIR}/verilator_out")
include_directories(${VERILATOR_OUT_DIR})
file(GLOB VERILATOR_GENERATED_SOURCES "${VERILATOR_OUT_DIR}/*.cpp")

pybind11_add_module(logos_emu
    src/emulator_core.cpp
    src/dpi_impl.cpp
    ${VERILATOR_GENERATED_SOURCES}
    ${VERILATOR_INCLUDE_DIR}/verilated.cpp
    ${VERILATOR_INCLUDE_DIR}/verilated_dpi.cpp
    ${VERILATOR_INCLUDE_DIR}/verilated_threads.cpp 
)
target_include_directories(logos_emu PRIVATE ${CMAKE_CURRENT_BINARY_DIR} ${VERILATOR_INCLUDE_DIR})
target_compile_options(logos_emu PRIVATE -fPIC)
target_link_libraries(logos_emu PRIVATE SEAL::seal)

# --- SEAL EXPORTER TOOL ---
add_executable(seal_exporter src/tools/seal_exporter.cpp)
target_link_libraries(seal_exporter PRIVATE SEAL::seal)
