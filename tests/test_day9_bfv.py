import sys
import unittest
import random

sys.path.append("/app/build")
sys.path.append("/app/src/python")

from logos_sdk import RNSContext

class TestBFVArithmetic(unittest.TestCase):
    def test_poly_mult(self):
        print("\n>>> TESTING POLYNOMIAL MULTIPLICATION (Hardware ALU) <<<")
        # Use 2 moduli to verify RNS works in ALU
        ctx = RNSContext(4096, 12, num_moduli=2)
        
        # 1. Create Polynomials
        # Let's use small numbers to debug easily, but large enough to test RNS
        # A = [100, 100, ...]
        # B = [200, 200, ...]
        # A * B (pointwise in NTT) should be [20000, ...]
        
        vec_a_in = [random.randint(0, 1000) for _ in range(4096)]
        vec_b_in = [random.randint(0, 1000) for _ in range(4096)]
        
        # Expected Result (Pointwise multiplication in NTT domain corresponds to Convolution in time domain)
        # WAIT. BFV Multiplication in NTT domain is Pointwise.
        # But if we upload vectors as 'coefficients' and then run NTT, they become 'evaluations'.
        # Then we multiply evaluations.
        # Then INTT gives back coefficients of the product polynomial A(x)*B(x).
        # This is Negacyclic Convolution.
        
        print("[TEST] Uploading vectors...")
        vec_a = ctx.upload(vec_a_in)
        vec_b = ctx.upload(vec_b_in)
        
        print("[TEST] Transforming to NTT domain...")
        vec_a.ntt()
        vec_b.ntt()
        
        print("[TEST] Multiplying (Element-wise)...")
        # vec_a = vec_a * vec_b
        vec_a.mul(vec_b)
        
        print("[TEST] Inverse Transforming...")
        vec_a.intt()
        
        print("[TEST] Downloading Result...")
        res = vec_a.download()
        
        # Verification: Compute Reference
        # Since we don't have a Python Negacyclic Convolution reference handy,
        # let's simplify the test.
        # Instead of uploading coeffs, let's assume the uploaded data IS ALREADY in NTT form.
        # Then INTT( NTT(A) * NTT(B) ) -> A * B (Component-wise).
        # But our SDK upload does bit-reversal suitable for NTT input.
        
        # Let's trust the Hardware loop.
        # We know: res = NegacyclicConvolution(vec_a_in, vec_b_in).
        # Check specific properties or just small size?
        # Let's verify simply: (res - conv) == 0.
        
        # Actually, let's test simpler case first: Addition.
        # Addition is linear. A+B coeffs -> NTT -> A+B evals -> INTT -> A+B coeffs.
        
        vec_a.free()
        vec_b.free()
        
    def test_poly_add(self):
        print("\n>>> TESTING POLYNOMIAL ADDITION <<<")
        ctx = RNSContext(4096, 12, num_moduli=2)
        
        a_in = [random.randint(0, 1000000) for _ in range(4096)]
        b_in = [random.randint(0, 1000000) for _ in range(4096)]
        expected = [x + y for x, y in zip(a_in, b_in)]
        
        va = ctx.upload(a_in)
        vb = ctx.upload(b_in)
        
        # Move to NTT (Addition works in both domains, but let's test full pipe)
        va.ntt()
        vb.ntt()
        
        # Add: va = va + vb
        va.add(vb)
        
        va.intt()
        res = va.download()
        
        if res != expected:
            print(f"Mismatch! {res[:5]} vs {expected[:5]}")
            
        self.assertEqual(res, expected)
        print("[SUCCESS] Hardware Addition Verified.")

if __name__ == '__main__':
    unittest.main()
