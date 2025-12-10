import sys
import unittest
import os

# Подгружаем сгенерированный конфиг
sys.path.append(os.getcwd())
import ntt_config_4k as cfg

sys.path.append("/app/build")
try:
    import logos_emu
except ImportError:
    print("CRITICAL: Could not import logos_emu.")
    sys.exit(1)

class TestScaling(unittest.TestCase):
    def setUp(self):
        self.emu = logos_emu.Emulator()
        self.N = cfg.N
        self.Q = cfg.Q
        self.PSI = cfg.PSI

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

    def soft_dit_ntt(self, input_arr):
        """Software Golden Model for DIT NTT"""
        a = list(input_arr)
        N_LOG = self.N.bit_length() - 1
        
        m = 2
        half_m = 1
        w_stride = self.N // 2
        
        for s in range(N_LOG):
            for k in range(0, self.N, m):
                for j in range(half_m):
                    u_idx = k + j
                    v_idx = k + j + half_m
                    
                    w_idx = j * w_stride
                    w = pow(self.PSI, w_idx, self.Q)
                    
                    u = a[u_idx]
                    v = a[v_idx]
                    
                    vw = (v * w) % self.Q
                    new_u = (u + vw) % self.Q
                    new_v = (u - vw) % self.Q
                    
                    a[u_idx] = new_u
                    a[v_idx] = new_v
            
            m <<= 1
            half_m <<= 1
            w_stride >>= 1
        return a

    def test_4k_ntt(self):
        print(f"\n[SCALING] Testing N={self.N}, Q={self.Q}")
        
        # 1. Input: Ramp [0..N-1]
        input_data = list(range(self.N))
        
        # 2. Bit Reverse
        hw_input = self.bit_reverse_array(input_data)
        
        # 3. Software Calc
        print("[SCALING] Calculating SW Reference...")
        expected = self.soft_dit_ntt(hw_input)
        
        # 4. Hardware Run
        ram_addr = 0x10000
        print("[SCALING] Writing to RAM...")
        self.emu.write_ram(ram_addr, hw_input)
        
        print("[SCALING] Running HW NTT (Simulating 4096 points)...")
        self.emu.run_ntt(ram_addr)
        
        print("[SCALING] Reading Result...")
        hw_result = self.emu.read_ram(ram_addr, self.N)
        
        # 5. Verify
        print(f"HW Head (first 5): {hw_result[:5]}")
        print(f"SW Head (first 5): {expected[:5]}")
        
        self.assertEqual(hw_result, expected)
        print("[PASS] N=4096 NTT Verified!")

if __name__ == '__main__':
    unittest.main()
