import sys
import os

# Ensure we can import the built module
sys.path.append("/app/build")

import alu_tester
import unittest

class TestVectorALU(unittest.TestCase):
    def setUp(self):
        self.Q = 1073750017 # Standard Phase 2 Q

    def test_add(self):
        # 100 + 200 = 300
        res = alu_tester.calc(0, 100, 200, self.Q)
        self.assertEqual(res, 300)
        
        # Overflow case: (Q-1) + 5 = 4
        res = alu_tester.calc(0, self.Q - 1, 5, self.Q)
        self.assertEqual(res, 4)
        print("[PASS] ADD Verified")

    def test_sub(self):
        # 300 - 100 = 200
        res = alu_tester.calc(1, 300, 100, self.Q)
        self.assertEqual(res, 200)

        # Underflow case: 5 - 10 = Q - 5
        res = alu_tester.calc(1, 5, 10, self.Q)
        self.assertEqual(res, self.Q - 5)
        print("[PASS] SUB Verified")

    def test_mult_barrett(self):
        # 10 * 10 = 100
        res = alu_tester.calc(2, 10, 10, self.Q)
        self.assertEqual(res, 100)

        # Big numbers: 1000 * 1000 = 1,000,000
        res = alu_tester.calc(2, 1000, 1000, self.Q)
        self.assertEqual(res, 1000000)

        # Modular wrapping
        # Let's take a known pair. 
        # A = 2^30, B = 2^30. 
        # Python check: (2**30 * 2**30) % 1073750017
        a = 2**30
        expected = (a * a) % self.Q
        res = alu_tester.calc(2, a, a, self.Q)
        self.assertEqual(res, expected)
        print(f"[PASS] MULT Verified (Barrett). {a}*{a} mod Q = {res}")

if __name__ == '__main__':
    print(f"Testing ALU with Q={1073750017}")
    unittest.main()
