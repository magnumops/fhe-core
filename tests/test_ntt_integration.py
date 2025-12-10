import sys
import unittest

sys.path.append("/app/build")
try:
    import ntt_engine_tester
except ImportError:
    print("CRITICAL: Could not import ntt_engine_tester.")
    sys.exit(1)

class TestNTTIntegration(unittest.TestCase):
    def setUp(self):
        self.sim = ntt_engine_tester.NTTEngineSim()
        self.N = 8
        self.Q = 17
        self.PSI = 3 # Hardware uses powers of 3 from ROM

    def bit_reverse(self, val, bits):
        res = 0
        for i in range(bits):
            if (val >> i) & 1:
                res |= (1 << (bits - 1 - i))
        return res

    def bit_reverse_array(self, arr):
        bits = self.N.bit_length() - 1
        res = [0] * self.N
        for i in range(self.N):
            res[self.bit_reverse(i, bits)] = arr[i]
        return res

    def soft_dit_ntt(self, input_arr):
        """Software implementation of Cooley-Tukey DIT to verify HW structure"""
        # 1. Copy input
        a = list(input_arr)
        
        # 2. Stages
        # Hardware logic:
        # Stage 1: m=2, half=1, stride=4.
        # Stage 2: m=4, half=2, stride=2.
        # Stage 3: m=8, half=4, stride=1.
        
        # Note: Input to DIT must be bit-reversed already? 
        # Actually, if we follow the HW logic trace from Day 5:
        # It iterates pairs (k, k+half_m). This IS the DIT structure.
        # So we process the array 'a' in place.
        
        n_log = 3
        
        # Emulate the 3 stages of HW
        # Stage 1
        m = 2
        half_m = 1
        w_stride = 4
        for k in range(0, self.N, m):
            for j in range(half_m):
                u_idx = k + j
                v_idx = k + j + half_m
                w_idx = j * w_stride
                
                u = a[u_idx]
                v = a[v_idx]
                w = pow(self.PSI, w_idx, self.Q) # Read from "Virtual ROM"
                
                # Butterfly
                vw = (v * w) % self.Q
                new_u = (u + vw) % self.Q
                new_v = (u - vw) % self.Q
                
                a[u_idx] = new_u
                a[v_idx] = new_v
                
        # Stage 2
        m = 4
        half_m = 2
        w_stride = 2
        for k in range(0, self.N, m):
            for j in range(half_m):
                u_idx = k + j
                v_idx = k + j + half_m
                w_idx = j * w_stride
                
                u = a[u_idx]
                v = a[v_idx]
                w = pow(self.PSI, w_idx, self.Q)
                
                vw = (v * w) % self.Q
                new_u = (u + vw) % self.Q
                new_v = (u - vw) % self.Q
                
                a[u_idx] = new_u
                a[v_idx] = new_v

        # Stage 3
        m = 8
        half_m = 4
        w_stride = 1
        for k in range(0, self.N, m):
            for j in range(half_m):
                u_idx = k + j
                v_idx = k + j + half_m
                w_idx = j * w_stride
                
                u = a[u_idx]
                v = a[v_idx]
                w = pow(self.PSI, w_idx, self.Q)
                
                vw = (v * w) % self.Q
                new_u = (u + vw) % self.Q
                new_v = (u - vw) % self.Q
                
                a[u_idx] = new_u
                a[v_idx] = new_v
                
        return a

    def test_ntt_n8_q17(self):
        input_data = [0, 1, 2, 3, 4, 5, 6, 7]
        
        # 1. Prepare Bit-Reversed Input for HW
        hw_input = self.bit_reverse_array(input_data)
        print(f"\n[TEST] Input (Natural): {input_data}")
        print(f"[TEST] Input (BitRev):  {hw_input}")
        
        # 2. Run Software DIT on the SAME bit-reversed input to verify structure
        # (Since HW starts with this memory state)
        expected_output = self.soft_dit_ntt(hw_input)
        
        # 3. Load HW
        self.sim.load_memory(hw_input)
        
        # 4. Run HW
        self.sim.run()
        
        # 5. Read Result
        hw_result = self.sim.read_memory(8)
        
        print(f"HW Result: {hw_result}")
        print(f"SW Model:  {expected_output}")
        
        self.assertEqual(hw_result, expected_output)
        print("[PASS] Hardware perfectly matches Software DIT Model!")

if __name__ == '__main__':
    unittest.main()
