import sys
import unittest
import random

sys.path.append("/app/build")
sys.path.append("/app/src/python")

from logos_sdk import LogosContext
import ntt_config_4k as cfg

class TestLogosSDK(unittest.TestCase):
    def test_high_level_flow(self):
        print("\n>>> TESTING LOGOS SDK (Day 6+7 Integration) <<<")
        
        ctx = LogosContext(cfg.N, cfg.Q, cfg.N_LOG)
        print(f"[SDK] Context Initialized. Q={cfg.Q}")
        
        # 1. Prepare Data
        input_vec = [random.randint(0, cfg.Q-1) for _ in range(cfg.N)]
        
        # 2. Upload (Host -> Device)
        # SDK auto-applies Bit-Reversal for NTT input
        vec_handle = ctx.upload(input_vec)
        print(f"[SDK] Uploaded to Slot {vec_handle.slot_id}")
        
        # 3. Operations: NTT -> INTT
        # NTT output is Natural.
        # INTT requires Bit-Reversed input.
        # SDK 'intt()' method automatically handles this via '_host_shuffle':
        #   Download (Natural) -> BitReverse (Host) -> Upload (BitReversed) -> INTT (Device)
        vec_handle.ntt().intt()
        
        # 4. Download Result
        print("[SDK] Downloading result...")
        result_raw = vec_handle.download()
        
        # 5. Verification
        # HARDWARE BEHAVIOR:
        # DIT INTT (Cooley-Tukey) produces Natural Order output from Bit-Reversed input.
        # So 'result_raw' is ALREADY in Natural Order.
        # No extra bit-reversal needed here.
        result_ordered = result_raw 
        
        if result_ordered != input_vec:
            print(f"Mismatch! First 5: {result_ordered[:5]} vs {input_vec[:5]}")
        
        self.assertEqual(result_ordered, input_vec)
        print("[SUCCESS] SDK Round-Trip Verified (Input == Output).")
        
        vec_handle.free()

if __name__ == '__main__':
    unittest.main()
