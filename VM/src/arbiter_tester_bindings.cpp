#include <pybind11/pybind11.h>
#include "Varbiter_test_shim.h"
#include "Varbiter_test_shim__Dpi.h" // FIXED: Include generated DPI headers
#include "verilated.h"
#include "dpi_impl.h" 
#include "isa_spec.h"

namespace py = pybind11;
VirtualRAM* g_ram = nullptr;
CommandQueue* g_queue = nullptr; 

class ArbiterTester {
    Varbiter_test_shim* top;
    VirtualRAM* ram;
public:
    ArbiterTester() {
        ram = new VirtualRAM();
        g_ram = ram;
        top = new Varbiter_test_shim;
        top->rst = 1; top->clk = 0;
        top->eval();
        top->rst = 0; top->eval();
    }
    ~ArbiterTester() { delete top; delete ram; }

    void write_ram_direct(uint64_t addr, uint64_t val) {
        std::vector<uint64_t> v(4096, 0);
        v[0] = val;
        ram->write(addr, v);
    }

    void set_req_0(bool req, bool rw, uint64_t addr, int len) {
        top->req_0 = req; top->rw_0 = rw; top->addr_0 = addr; top->len_0 = len;
    }
    void set_req_1(bool req, bool rw, uint64_t addr, int len) {
        top->req_1 = req; top->rw_1 = rw; top->addr_1 = addr; top->len_1 = len;
    }
    
    void set_client_data(int client, int idx, uint64_t val) {
        svSetScope(svGetScopeFromName("TOP.arbiter_test_shim"));
        if (client == 0) set_wdata_0(idx, val);
        else set_wdata_1(idx, val);
    }
    
    uint64_t get_client_data(int client, int idx) {
        svSetScope(svGetScopeFromName("TOP.arbiter_test_shim"));
        if (client == 0) return get_rdata_0(idx);
        else return get_rdata_1(idx);
    }

    bool get_ack(int client) {
        return (client == 0) ? top->ack_0 : top->ack_1;
    }

    void step() {
        top->clk = 0; top->eval();
        top->clk = 1; top->eval();
    }
};

PYBIND11_MODULE(arbiter_test, m) {
    py::class_<ArbiterTester>(m, "ArbiterTester")
        .def(py::init<>())
        .def("write_ram_direct", &ArbiterTester::write_ram_direct)
        .def("set_req_0", &ArbiterTester::set_req_0)
        .def("set_req_1", &ArbiterTester::set_req_1)
        .def("set_client_data", &ArbiterTester::set_client_data)
        .def("get_client_data", &ArbiterTester::get_client_data)
        .def("get_ack", &ArbiterTester::get_ack)
        .def("step", &ArbiterTester::step);
}
