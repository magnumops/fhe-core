import struct
import logos_emu

class LogosAccelerator:
    def __init__(self, modulus):
        self.sim = logos_emu.LogosContext()
        self.sim.reset_state()
        self.modulus = modulus
        logos_emu.set_modulus(modulus)
        
        # Memory Map
        self.SLOT0_ADDR = 0x1000
        self.SLOT1_ADDR = 0x2000
        self.RES_ADDR   = 0x8000
        
        # OpCodes
        self.OP_LOAD = 2
        self.OP_SUB  = 6
        self.OP_MULT = 7
        
    def load_vector(self, data, slot=0):
        target_addr = self.SLOT0_ADDR if slot == 0 else self.SLOT1_ADDR
        print(f"[SDK] Loading {len(data)} words to Slot {slot}...")
        
        # 1. Write to Global RAM
        for i, val in enumerate(data):
            logos_emu.write_ram(target_addr + i*8, val)
            
        # 2. Trigger DMA Load
        self.sim.push_command(self.OP_LOAD, slot, target_addr, 0)
        self._wait_cycles(5000)
        
    def subtract(self):
        print("[SDK] Executing SUB (Slot0 - Slot1)...")
        self.sim.push_command(self.OP_SUB, 0, 0, 0)
        self._wait_cycles(100)
        
    def square(self):
        print("[SDK] Executing SQUARE (Slot0 ^ 2)...")
        self.sim.push_command(self.OP_MULT, 0, 0, 0)
        self._wait_cycles(100)
        
    def read_result(self, length):
        print("[SDK] Reading Result...")
        res = []
        for i in range(length):
            val = logos_emu.read_ram(self.RES_ADDR + i*8)
            res.append(val)
        return res
        
    def _wait_cycles(self, n):
        for _ in range(n): self.sim.tick()

def load_bin(filename):
    with open(filename, 'rb') as f:
        c = f.read()
        return list(struct.unpack(f'<{len(c)//8}Q', c))
