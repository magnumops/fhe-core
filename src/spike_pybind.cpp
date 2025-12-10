#include <pybind11/pybind11.h>
#include <string>

namespace py = pybind11;

// Простая функция сложения
int add(int i, int j) {
    return i + j;
}

// Простая функция с текстом
std::string greet(const std::string& name) {
    return "Hello, " + name + "! From C++ inside Docker.";
}

// Макрос PyBind11 для создания модуля
PYBIND11_MODULE(spike_pybind, m) {
    m.doc() = "Day 2 Spike: PyBind11 Test Module"; // docstring
    m.def("add", &add, "A function that adds two numbers");
    m.def("greet", &greet, "A function that greets");
}
