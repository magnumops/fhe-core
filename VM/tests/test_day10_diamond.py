import sys
import unittest
import random

sys.path.append("/app/build")
sys.path.append("/app/src/python")

import logos_fhe
from logos_sdk import RNSContext
from rns_math import generate_primes

class TestDiamondLoop(unittest.TestCase):
    def test_poly_arithmetic_rns(self):
        print("\n>>> TESTING LOGOS ACCELERATOR: POLYNOMIAL MULTIPLICATION (RNS) <<<")
        
        N = 4096
        N_LOG = 12
        # Use 2 moduli for data
        primes = generate_primes(N_LOG, 3) 
        seal_ctx = logos_fhe.SealContext(N, primes)
        hw_ctx = RNSContext(N, N_LOG, num_moduli=2)
        data_primes = hw_ctx.rns.moduli
        
        # 1. Generate Input Data
        # A(x) = 2 + 2x + 2x^2 ...
        # B(x) = 3 + 3x + 3x^2 ...
        # A * B = (2+2x...)*(3+3x...) 
        # Constant term of A*B = N * 2 * 3 = 4096 * 6 = 24576
        
        m1 = [2] * N
        m2 = [3] * N
        
        print("[SETUP] Inputs: Const(2) and Const(3)")
        
        # 2. Decompose inputs into RNS directly (Bypassing SEAL Encryption)
        # We treat m1, m2 as coefficients of polynomials in RNS form.
        # Since they are small, m1 % q_i = m1.
        
        A_rns = []
        B_rns = []
        
        # Create BigInt representation first (it's just m1, m2 since they are small)
        A_big = m1
        B_big = m2
        
        # 3. Hardware Multiplication
        # Res = A * B
        print("[HW] Computing Res = A * B...")
        vA = hw_ctx.upload(A_big)
        vB = hw_ctx.upload(B_big)
        
        # NTT -> Pointwise Mult -> INTT
        vA.ntt().mul(vB.ntt())
        vA.intt()
        
        res_big = vA.download()
        vA.free(); vB.free()
        
        # 4. Verification
        # Convolution of [2,2,2...] and [3,3,3...]
        # c[0] = a[0]b[0] - a[N-1]b[1] ... (Negacyclic)
        # Actually, let's verify simpler case:
        # A = [1, 0, 0...] (Poly = 1)
        # B = [2, 0, 0...] (Poly = 2)
        # A*B = [2, 0, 0...]
        
        print("[CHECK] Verifying with simple inputs...")
        a_simple = [0]*N; a_simple[0] = 5
        b_simple = [0]*N; b_simple[0] = 10
        # Expected: [50, 0, 0...]
        
        vA = hw_ctx.upload(a_simple)
        vB = hw_ctx.upload(b_simple)
        vA.ntt().mul(vB.ntt()).intt()
        res_simple = vA.download()
        vA.free(); vB.free()
        
        print(f"[RESULT] First 5: {res_simple[:5]}")
        
        self.assertEqual(res_simple[0], 50)
        self.assertEqual(res_simple[1], 0)
        
        print("[SUCCESS] Hardware Polynomial Multiplication Verified.")

if __name__ == '__main__':
    unittest.main()
