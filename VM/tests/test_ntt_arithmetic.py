import sys
import unittest

sys.path.append("/app/build")
try:
    import ntt_tester
except ImportError:
    print("CRITICAL: Could not import ntt_tester.")
    sys.exit(1)

class TestVerilogArithmetic(unittest.TestCase):
    def setUp(self):
        self.sim = ntt_tester.NTTSimulator()
        self.q = 17 

    def test_basic_ops(self):
        # Add: 10 + 15 mod 17 = 8
        res = self.sim.step(0, 10, 15, 0, self.q)
        self.assertEqual(res[0], 8)
        
        # Mult: 3 * 6 mod 17 = 1
        res = self.sim.step(1, 3, 6, 0, self.q)
        self.assertEqual(res[0], 1)

        # Sub: 5 - 10 mod 17 = -5 = 12
        res = self.sim.step(2, 5, 10, 0, self.q)
        self.assertEqual(res[0], 12)
        print("\n[PASS] Add/Sub/Mult Verified")

    def test_butterfly(self):
        # Butterfly(U, V, W) -> (U + VW, U - VW)
        # U=2, V=5, W=3 (Twiddle), Q=17
        # VW = 5*3 = 15
        # X = 2 + 15 = 17 = 0
        # Y = 2 - 15 = -13 = 4
        
        res = self.sim.step(3, 2, 5, 3, self.q)
        print(f"\nButterfly(2, 5, 3) -> {res}")
        self.assertEqual(res[0], 0)
        self.assertEqual(res[1], 4)
        print("[PASS] Butterfly Unit Verified")

if __name__ == '__main__':
    unittest.main()
