cmake_minimum_required(VERSION 3.10)
project(logos_vm)

set(CMAKE_CXX_STANDARD 17)

# Находим Python (нужен для PyBind11)
find_package(Python3 COMPONENTS Interpreter Development REQUIRED)

# Находим PyBind11 (мы установили его через pip, но CMake умеет искать и так)
# Если не найдет автоматом, используем pybind11_add_module напрямую,
# так как pip ставит хедеры в системные пути.
# Попробуем самый надежный способ для Docker окружения:
execute_process(
    COMMAND "${Python3_EXECUTABLE}" -m pybind11 --cmakedir
    OUTPUT_VARIABLE pybind11_DIR
    OUTPUT_STRIP_TRAILING_WHITESPACE
)
list(APPEND CMAKE_PREFIX_PATH "${pybind11_DIR}")
find_package(pybind11 REQUIRED)

# Создаем модуль spike_pybind
pybind11_add_module(spike_pybind src/spike_pybind.cpp)
