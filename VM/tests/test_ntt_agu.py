import sys
import unittest

sys.path.append("/app/build")
try:
    import ntt_agu_tester
except ImportError:
    print("CRITICAL: Could not import ntt_agu_tester.")
    sys.exit(1)

class TestAGU(unittest.TestCase):
    def setUp(self):
        self.sim = ntt_agu_tester.AGUSimulator()
        
        # Загружаем эталон
        self.expected_trace = []
        with open("agu_trace.txt", "r") as f:
            for line in f:
                self.expected_trace.append(list(map(int, line.split())))

    def test_agu_sequence(self):
        print("\n[TEST] Starting AGU Hardware Simulation...")
        self.sim.start()
        
        trace_idx = 0
        max_ticks = 50 # Watchdog
        
        for t in range(max_ticks):
            valid, u, v, w, done = self.sim.tick()
            
            if done:
                print(f"Tick {t}: DONE signal received.")
                break
                
            if valid:
                if trace_idx >= len(self.expected_trace):
                    self.fail("Hardware produced more addresses than expected!")
                
                exp_u, exp_v, exp_w = self.expected_trace[trace_idx]
                
                print(f"Tick {t}: HW({u}, {v}, {w}) vs REF({exp_u}, {exp_v}, {exp_w})")
                
                self.assertEqual(u, exp_u, f"U mismatch at index {trace_idx}")
                self.assertEqual(v, exp_v, f"V mismatch at index {trace_idx}")
                self.assertEqual(w, exp_w, f"W mismatch at index {trace_idx}")
                
                trace_idx += 1
        
        self.assertEqual(trace_idx, len(self.expected_trace), "Hardware produced fewer addresses than expected!")
        print("[PASS] AGU Sequence matches Python Reference perfectly.")

if __name__ == '__main__':
    unittest.main()
