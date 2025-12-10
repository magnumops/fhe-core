import sys
import unittest
import os

sys.path.append("/app/build")
try:
    import ntt_tester
except ImportError:
    print("CRITICAL: Could not import ntt_tester.")
    sys.exit(1)

class TestVerilogArithmetic(unittest.TestCase):
    def setUp(self):
        self.sim = ntt_tester.NTTSimulator()
        self.q = 17 

    def test_rom_loading(self):
        # Opcode 4: Read ROM
        # We expect powers of 3: 3^0=1, 3^1=3, 3^2=9, 3^3=27=10, ...
        
        expected = [
            1,          # 3^0
            3,          # 3^1
            9,          # 3^2
            27 % 17,    # 3^3 = 10
            81 % 17,    # 3^4 = 13
            243 % 17,   # 3^5 = 5
            729 % 17,   # 3^6 = 15
            2187 % 17   # 3^7 = 11
        ]
        
        print("\n[TEST] Verifying ROM Data...")
        for addr in range(8):
            # Pass addr in op_a
            res = self.sim.step(4, addr, 0, 0, self.q)
            val = res[0]
            print(f"ADDR {addr}: Expected {expected[addr]}, Got {val}")
            self.assertEqual(val, expected[addr])
        
        print("[PASS] ROM Loaded Successfully")

if __name__ == '__main__':
    unittest.main()
