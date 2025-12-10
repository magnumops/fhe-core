import sys
import random
import unittest

sys.path.append("/app/src/python")
from rns_math import RNSBase, generate_primes

class TestRNSMath(unittest.TestCase):
    def test_crt_roundtrip(self):
        print("\n>>> TESTING RNS MATH (CRT) <<<")
        
        # 1. Generate 3 primes for N=4096 (12 bits)
        primes = generate_primes(12, 3)
        print(f"[RNS] Moduli: {primes}")
        
        rns = RNSBase(primes)
        print(f"[RNS] Total Modulus Q size: {rns.Q.bit_length()} bits")
        
        # 2. Test Values
        inputs = [
            0,
            1,
            rns.Q - 1,
            random.randint(0, rns.Q - 1),
            12345678901234567890
        ]
        
        for val in inputs:
            residues = rns.decompose(val)
            reconstructed = rns.compose(residues)
            self.assertEqual(val, reconstructed, f"Failed for {val}")
            
        print("[SUCCESS] CRT Round-Trip Verified.")

if __name__ == '__main__':
    unittest.main()
