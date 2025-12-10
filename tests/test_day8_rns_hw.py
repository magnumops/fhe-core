import sys
import unittest
import random

sys.path.append("/app/build")
sys.path.append("/app/src/python")

from logos_sdk import RNSContext

class TestRNSHardware(unittest.TestCase):
    def test_rns_pipeline(self):
        print("\n>>> TESTING RNS HARDWARE PIPELINE (2 Moduli) <<<")
        ctx = RNSContext(4096, 12, num_moduli=2)
        limit = ctx.rns.Q - 1
        print(f"[TEST] Max Value: {limit}")
        
        input_vec = [random.randint(0, limit) for _ in range(4096)]
        
        print("[TEST] Uploading...")
        vec = ctx.upload(input_vec)
        
        print("[TEST] Running NTT...")
        vec.ntt()
        
        print("[TEST] Running INTT...")
        vec.intt()
        
        print("[TEST] Downloading...")
        result = vec.download()
        
        if result != input_vec:
            print(f"Mismatch! First 5: {result[:5]} vs {input_vec[:5]}")
            delta = [r - i for r, i in zip(result, input_vec)]
            print(f"Delta: {delta[:5]}")
            
        self.assertEqual(result, input_vec)
        print("[SUCCESS] RNS Hardware Round-Trip Verified.")
        vec.free()

if __name__ == '__main__':
    unittest.main()
