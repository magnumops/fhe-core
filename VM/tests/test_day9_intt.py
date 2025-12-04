import sys
import unittest
import os
sys.path.append(os.getcwd())
import ntt_config_4k as cfg

sys.path.append("/app/build")
try:
    import logos_emu
except ImportError:
    print("CRITICAL: Could not import logos_emu.")
    sys.exit(1)

class TestINTT(unittest.TestCase):
    def setUp(self):
        self.emu = logos_emu.Emulator()
        self.N = cfg.N

    def bit_reverse_array(self, arr):
        bits = self.N.bit_length() - 1
        res = [0] * self.N
        for i in range(self.N):
            rev = 0
            val = i
            for _ in range(bits):
                rev = (rev << 1) | (val & 1)
                val >>= 1
            res[rev] = arr[i]
        return res

    def test_round_trip(self):
        print(f"\n[DAY 9] Testing Round Trip (Identity) for N={self.N}")
        
        # 1. Input Data (Randomish)
        data_in = [(i * 123 + 456) % cfg.Q for i in range(self.N)]
        
        # 2. Forward NTT (Requires Bit-Reversed Input)
        hw_in_fwd = self.bit_reverse_array(data_in)
        
        addr = 0x1000
        self.emu.write_ram(addr, hw_in_fwd)
        
        print("[DAY 9] Running Forward NTT...")
        self.emu.run_ntt(addr, 0) # Mode 0 = NTT
        
        # Read intermediate result (in Frequency Domain)
        ntt_result = self.emu.read_ram(addr, self.N)
        
        # 3. Inverse NTT
        # Note: INTT input must be Bit-Reversed?
        # Cooley-Tukey DIT Output is in Natural Order.
        # Inverse DIT Input needs Bit-Reversed Order?
        # Yes, standard DIT structure is symmetric.
        # But our HW output is in Natural Order (due to DIT structure: BitRev Input -> Natural Output).
        # So for INTT, we need to Bit-Reverse the ntt_result before feeding it back?
        # YES. DIT always goes BitRev -> Natural.
        
        hw_in_inv = self.bit_reverse_array(ntt_result)
        self.emu.write_ram(addr, hw_in_inv)
        
        print("[DAY 9] Running Inverse NTT...")
        self.emu.run_ntt(addr, 1) # Mode 1 = INTT
        
        final_result = self.emu.read_ram(addr, self.N)
        
        # 4. Verify Identity
        print(f"Input Head: {data_in[:5]}")
        print(f"Final Head: {final_result[:5]}")
        
        self.assertEqual(final_result, data_in)
        print("[PASS] Identity Verified: INTT(NTT(x)) == x")

if __name__ == '__main__':
    unittest.main()
