import sys
import unittest

sys.path.append("/app/build")
try:
    import logos_emu
except ImportError:
    print("CRITICAL: Could not import logos_emu.")
    sys.exit(1)

class TestFullStackNTT(unittest.TestCase):
    def setUp(self):
        self.emu = logos_emu.Emulator()
        self.N = 8

    def bit_reverse_array(self, arr):
        bits = self.N.bit_length() - 1
        res = [0] * self.N
        for i in range(self.N):
            # Simple bit reverse
            rev = 0
            val = i
            for _ in range(bits):
                rev = (rev << 1) | (val & 1)
                val >>= 1
            res[rev] = arr[i]
        return res

    def test_integration(self):
        # 1. Prepare Data
        input_data = [0, 1, 2, 3, 4, 5, 6, 7]
        # Bit-Reverse BEFORE sending to HW
        hw_input = self.bit_reverse_array(input_data)
        
        print(f"\n[FULL STACK] Original: {input_data}")
        print(f"[FULL STACK] BitReved: {hw_input}")
        
        # 2. Write to 1TB Virtual RAM (Offset 0x1000)
        ram_addr = 0x1000
        self.emu.write_ram(ram_addr, hw_input)
        
        # 3. Trigger Hardware NTT
        print("[FULL STACK] Triggering NTT Engine via DPI...")
        self.emu.run_ntt(ram_addr)
        
        # 4. Read Result back from RAM
        hw_result = self.emu.read_ram(ram_addr, self.N)
        print(f"[FULL STACK] Result in RAM: {hw_result}")
        
        # 5. Verify against Day 6 Golden Result (DIT Model)
        # Expected: [11, 10, 11, 12, 13, 12, 15, 1]
        expected = [11, 10, 11, 12, 13, 12, 15, 1]
        
        self.assertEqual(hw_result, expected)
        print("[PASS] Full Stack Integration Successful!")

if __name__ == '__main__':
    unittest.main()
