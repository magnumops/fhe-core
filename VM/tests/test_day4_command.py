import sys
import time
import random
import unittest

# Ensure we can import the built module
sys.path.append("/app/build")

import logos_emu
import ntt_config_4k as cfg

# === HELPER: BIT REVERSAL ===
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

class TestCommandProcessor(unittest.TestCase):
    def setUp(self):
        # Create Emulator instance (Resets RTL)
        self.emu = logos_emu.Emulator()
        # Set Context (Q, MU, N_INV)
        self.mu = (1 << 64) // cfg.Q
        self.emu.set_context(cfg.Q, self.mu, cfg.N_INV)
        print(f"\n[SETUP] Context Loaded: Q={cfg.Q}")

    def test_ntt_intt_loop(self):
        print(">>> TESTING COMMAND STREAM: NTT -> HALT -> INTT -> HALT")
        
        # 1. Prepare Data
        input_vec = [random.randint(0, cfg.Q-1) for _ in range(cfg.N)]
        # Hardware expects Bit-Reversed input for NTT (DIT)
        vec_rev = bit_reverse_permutation(input_vec)
        self.emu.write_ram(0, vec_rev)
        
        # 2. Schedule NTT Command
        print("[CMD] Pushing NTT...")
        self.emu.push_ntt_op(0, 0) # Addr=0, Mode=0 (NTT)
        self.emu.push_halt()
        
        # 3. Execute
        t0 = time.time()
        self.emu.run()
        t1 = time.time()
        print(f"[RUN] NTT Finished in {(t1-t0)*1000:.2f}ms")
        
        # 4. Verify Intermediate Result
        ntt_res = self.emu.read_ram(0, cfg.N)
        self.assertNotEqual(ntt_res, vec_rev, "Data should change after NTT")
        
        # 5. Prepare for INTT
        # To run INTT, we need to reset the Core (exit HALT state).
        # We re-instantiate Emulator. RAM persists (static global).
        del self.emu
        self.emu = logos_emu.Emulator()
        # Restore context (registers are reset)
        self.emu.set_context(cfg.Q, self.mu, cfg.N_INV)
        
        # Hardware outputs Natural order. INTT (Cooley-Tukey) needs Bit-Reversed input.
        # We must read, reverse, and write back.
        ntt_res_rev = bit_reverse_permutation(ntt_res)
        self.emu.write_ram(0, ntt_res_rev)
        
        # 6. Schedule INTT Command
        print("[CMD] Pushing INTT...")
        self.emu.push_ntt_op(0, 1) # Addr=0, Mode=1 (INTT)
        self.emu.push_halt()
        
        # 7. Execute
        t2 = time.time()
        self.emu.run()
        t3 = time.time()
        print(f"[RUN] INTT Finished in {(t3-t2)*1000:.2f}ms")
        
        # 8. Verify Final Result
        final_res = self.emu.read_ram(0, cfg.N)
        
        # Check against original
        if final_res != input_vec:
            print(f"Mismatch! First 5 expected: {input_vec[:5]}")
            print(f"Got: {final_res[:5]}")
        
        self.assertEqual(final_res, input_vec, "Round Trip Failed!")
        print("[SUCCESS] Platinum Loop via Command Processor Verified.")

if __name__ == '__main__':
    unittest.main()
