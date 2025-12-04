import sys
import time
import random

sys.path.append("/app/build")
import logos_emu
import ntt_config_4k as cfg

def bit_reverse_permutation(arr):
    n = len(arr)
    result = [0] * n
    for i in range(n):
        rev = 0
        temp = i
        for _ in range(cfg.N_LOG):
            rev = (rev << 1) | (temp & 1)
            temp >>= 1
        result[rev] = arr[i]
    return result

class PlatinumTester:
    def __init__(self):
        self.emu = logos_emu.Emulator()
        # Calculate Barrett Constant (MU)
        self.mu = (1 << 64) // cfg.Q
        print(f"[INIT] Q={cfg.Q}, MU={self.mu}, N_INV={cfg.N_INV}")
        
    def run_cycle(self, name, input_vec):
        print(f"\n[{name}] Size: {len(input_vec)}")
        
        bit_reversed_vec = bit_reverse_permutation(input_vec)
        self.emu.write_ram(0, bit_reversed_vec)
        
        t0 = time.time()
        # Pass ALL params: mode, Q, MU, N_INV
        self.emu.run_ntt(0, 0, cfg.Q, self.mu, cfg.N_INV) 
        t1 = time.time()
        
        ntt_result = self.emu.read_ram(0, cfg.N)
        ntt_result_rev = bit_reverse_permutation(ntt_result)
        self.emu.write_ram(0, ntt_result_rev)
        
        t2 = time.time()
        # INTT Mode
        self.emu.run_ntt(0, 1, cfg.Q, self.mu, cfg.N_INV)
        t3 = time.time()
        
        final_res = self.emu.read_ram(0, cfg.N)
        
        match = (final_res == input_vec)
        print(f"[{name}] Match: {match}")
        if not match:
            print(f"Mismatch! First 5: {final_res[:5]} vs {input_vec[:5]}")
            exit(1)
            
        print(f"[{name}] Timing: NTT={(t1-t0)*1000:.2f}ms, INTT={(t3-t2)*1000:.2f}ms")

if __name__ == "__main__":
    print(f"=== STARTING PLATINUM LOOP (N={cfg.N}) ===\n")
    tester = PlatinumTester()
    tester.run_cycle("ZERO_VEC", [0]*cfg.N)
    tester.run_cycle("ONES_VEC", [1]*cfg.N)
    rand_vec = [random.randint(0, cfg.Q-1) for _ in range(cfg.N)]
    tester.run_cycle("RAND_VEC_1", rand_vec)
    high_vec = [cfg.Q - 1 - i for i in range(cfg.N)]
    tester.run_cycle("HIGH_VAL_VEC", high_vec)
    print("\n=== PLATINUM LOOP COMPLETE: ALL SYSTEMS NOMINAL ===")
