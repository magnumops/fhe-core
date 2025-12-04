import sys
import unittest
import os
import random
import time

sys.path.append(os.getcwd())
import ntt_config_4k as cfg

sys.path.append("/app/build")
try:
    import logos_emu
except ImportError:
    print("CRITICAL: Could not import logos_emu.")
    sys.exit(1)

class PlatinumLoop(unittest.TestCase):
    def setUp(self):
        self.emu = logos_emu.Emulator()
        self.N = cfg.N
        self.Q = cfg.Q

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

    def run_round_trip(self, name, data_in):
        print(f"\n[{name}] Size: {len(data_in)}")
        
        # 1. Forward NTT
        hw_in_fwd = self.bit_reverse_array(data_in)
        addr = 0x1000
        self.emu.write_ram(addr, hw_in_fwd)
        
        t0 = time.time()
        self.emu.run_ntt(addr, 0) # NTT
        t_ntt = time.time() - t0
        
        ntt_result = self.emu.read_ram(addr, self.N)
        
        # 2. Inverse NTT
        hw_in_inv = self.bit_reverse_array(ntt_result)
        self.emu.write_ram(addr, hw_in_inv)
        
        t0 = time.time()
        self.emu.run_ntt(addr, 1) # INTT
        t_intt = time.time() - t0
        
        final_result = self.emu.read_ram(addr, self.N)
        
        # 3. Verify
        is_match = (final_result == data_in)
        print(f"[{name}] Match: {is_match}")
        print(f"[{name}] Timing: NTT={t_ntt*1000:.2f}ms, INTT={t_intt*1000:.2f}ms")
        
        if not is_match:
            print(f"Input Head: {data_in[:5]}")
            print(f"Final Head: {final_result[:5]}")
            self.fail(f"[{name}] Identity Check Failed")

    def test_platinum_vectors(self):
        print("\n=== STARTING PLATINUM LOOP (N=4096) ===")
        
        # Case 1: Zero Vector
        self.run_round_trip("ZERO_VEC", [0] * self.N)
        
        # Case 2: Ones Vector
        self.run_round_trip("ONES_VEC", [1] * self.N)
        
        # Case 3: Random Vector 1
        rand1 = [random.randint(0, self.Q - 1) for _ in range(self.N)]
        self.run_round_trip("RAND_VEC_1", rand1)
        
        # Case 4: Random Vector 2 (Edge cases near Q)
        rand2 = [random.randint(self.Q - 100, self.Q - 1) for _ in range(self.N)]
        self.run_round_trip("HIGH_VAL_VEC", rand2)
        
        print("\n=== PLATINUM LOOP COMPLETE: ALL SYSTEMS NOMINAL ===")

if __name__ == '__main__':
    unittest.main()
