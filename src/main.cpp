#include <pybind11/pybind11.h>

namespace py = pybind11;

// Forward declaration
void init_fhe(py::module &m);

// Existing logos_emu init is handled by PYBIND11_MODULE macro in emulator_core.cpp
// Wait, we have two PYBIND11_MODULE definitions?
// emulator_core.cpp defines 'logos_emu'.
// We need to merge them or create a separate module 'logos_fhe'.
// Let's create 'logos_fhe' for SEAL wrapper to avoid recompiling emulator_core messily.

PYBIND11_MODULE(logos_fhe, m) {
    init_fhe(m);
}
