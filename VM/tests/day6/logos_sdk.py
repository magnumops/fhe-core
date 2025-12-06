# Logos SDK - High Level Driver for Phase 6
import sys

class LogosDriver:
    # Opcodes
    OPC_LOAD   = 0x02
    OPC_STORE  = 0x03
    OPC_LOAD_W = 0x04
    OPC_NTT    = 0x10
    OPC_INTT   = 0x11

    def __init__(self, emu_module):
        self.ctx = emu_module.LogosContext()
        self.ctx.reset()
        self.emu = emu_module # Access to static methods like write_ram

    def write_ram(self, addr, val):
        self.emu.write_ram(addr, val)

    def run_cycles(self, n):
        self.ctx.run_cycles(n)

    def _send(self, op, slot, target, addr, timeout=200000):
        # Format: [Op 8][Slot 4][Target 1][Addr 48]
        cmd = (op << 56) | (slot << 52) | (target << 48) | (addr & 0xFFFFFFFFFFFF)
        self.ctx.push_command(cmd, timeout)

    def load_data(self, core_id, slot, addr):
        print(f"[SDK] Core {core_id}: Load Data Slot {slot} <- RAM 0x{addr:X}")
        self._send(self.OPC_LOAD, slot, core_id, addr)

    def load_twiddles(self, core_id, addr):
        print(f"[SDK] Core {core_id}: Load Twiddles <- RAM 0x{addr:X}")
        # Twiddles (8192 words) take time. Timeout handled by default or arg.
        self._send(self.OPC_LOAD_W, 0, core_id, addr)

    def run_ntt(self, core_id):
        print(f"[SDK] Core {core_id}: Start NTT")
        self._send(self.OPC_NTT, 0, core_id, 0)
        
    def get_ops(self, core_id):
        return self.ctx.get_core_ops(core_id)
