import sys
import time
import random
import unittest

sys.path.append("/app/build")
import logos_emu
import ntt_config_4k as cfg

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

class TestMultiBank(unittest.TestCase):
    def setUp(self):
        self.emu = logos_emu.Emulator()
        self.mu = (1 << 64) // cfg.Q
        self.emu.set_context(cfg.Q, self.mu, cfg.N_INV)

    def test_bank_isolation(self):
        print(">>> TESTING MULTI-BANK ISOLATION (Slot 0 vs Slot 1)")
        
        vec_a = [1] * cfg.N
        vec_a_rev = bit_reverse_permutation(vec_a)
        
        vec_b = [random.randint(0, cfg.Q-1) for _ in range(cfg.N)]
        vec_b_rev = bit_reverse_permutation(vec_b)
        
        HOST_ADDR_A = 0
        HOST_ADDR_B = cfg.N 
        
        self.emu.write_ram(HOST_ADDR_A, vec_a_rev)
        self.emu.write_ram(HOST_ADDR_B, vec_b_rev)
        
        # SLOT 0 Operations
        self.emu.push_load_op(0, HOST_ADDR_A) 
        self.emu.push_ntt_op(0, 0)            
        self.emu.push_store_op(0, HOST_ADDR_A) 
        
        # SLOT 1 Operations
        self.emu.push_load_op(1, HOST_ADDR_B) 
        self.emu.push_ntt_op(1, 0)            
        self.emu.push_store_op(1, HOST_ADDR_B) 
        
        self.emu.push_halt()
        
        print("[RUN] Executing batch...")
        self.emu.run()
        
        res_a = self.emu.read_ram(HOST_ADDR_A, cfg.N)
        res_b = self.emu.read_ram(HOST_ADDR_B, cfg.N)
        
        self.assertNotEqual(res_a, vec_a_rev)
        self.assertNotEqual(res_b, vec_b_rev)
        self.assertNotEqual(res_a, res_b)
        
        print("[SUCCESS] Multi-Bank Operations Verified.")

if __name__ == '__main__':
    unittest.main()
