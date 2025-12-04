import sys
import os
import unittest

# Добавляем путь к so модулю
sys.path.append("/app/build")

try:
    import ntt_tester
except ImportError:
    print("CRITICAL: Could not import ntt_tester. Did the build succeed?")
    sys.exit(1)

class TestVerilogArithmetic(unittest.TestCase):
    def setUp(self):
        self.sim = ntt_tester.NTTSimulator()
        self.q = 17 # Prime used in Day 1 Golden Model

    def test_mod_add(self):
        # 10 + 15 mod 17 = 25 mod 17 = 8
        res = self.sim.step(0, 10, 15, self.q)
        self.assertEqual(res, 8)
        
        # 5 + 5 mod 17 = 10
        res = self.sim.step(0, 5, 5, self.q)
        self.assertEqual(res, 10)
        
        print("\n[PASS] Modular Addition Verified")

    def test_mod_mult(self):
        # 3 * 6 mod 17 = 18 mod 17 = 1
        res = self.sim.step(1, 3, 6, self.q)
        self.assertEqual(res, 1)
        
        # 16 * 16 mod 17 = (-1 * -1) = 1
        res = self.sim.step(1, 16, 16, self.q)
        self.assertEqual(res, 1)

        # 1337 * 0 mod 17 = 0
        res = self.sim.step(1, 1337, 0, self.q)
        self.assertEqual(res, 0)
        
        print("\n[PASS] Modular Multiplication Verified")

if __name__ == '__main__':
    unittest.main()
