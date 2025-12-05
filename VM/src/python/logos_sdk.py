import sys
import logos_emu
from rns_math import RNSBase, generate_primes, generate_twiddles

class RNSVector:
    def __init__(self, ctx, slots, size):
        self.ctx = ctx
        self.slots = slots
        self.size = size

    def ntt(self):
        for i, slot_id in enumerate(self.slots):
            # 1. Context Switch (Params + Twiddles)
            self.ctx.switch_context(i)
            
            # 2. Run NTT
            self.ctx.emu.push_ntt_op(slot_id, 0)
            self.ctx.emu.push_halt()
            self.ctx.emu.run()
            self.ctx.emu.reset_state()
        return self

    def intt(self):
        for i, slot_id in enumerate(self.slots):
            self.ctx.switch_context(i)
            
            # Hybrid Bit-Reversal
            host_addr = slot_id * self.size
            self.ctx.emu.push_store_op(slot_id, host_addr)
            self.ctx.emu.push_halt()
            self.ctx.emu.run()
            self.ctx.emu.reset_state()
            
            data = self.ctx.emu.read_ram(host_addr, self.size)
            rev_data = self.ctx._bit_reverse(data)
            self.ctx.emu.write_ram(host_addr, rev_data)
            self.ctx.emu.push_load_op(slot_id, host_addr)
            
            self.ctx.emu.push_ntt_op(slot_id, 1) # Mode 1 = INTT
            self.ctx.emu.push_halt()
            self.ctx.emu.run()
            self.ctx.emu.reset_state()
        return self

    def download(self):
        residues_matrix = []
        for slot_id in self.slots:
            host_addr = slot_id * self.size
            self.ctx.emu.push_store_op(slot_id, host_addr)
            self.ctx.emu.push_halt()
            self.ctx.emu.run()
            self.ctx.emu.reset_state()
            vec = self.ctx.emu.read_ram(host_addr, self.size)
            residues_matrix.append(vec)
            
        result = []
        for i in range(self.size):
            r_vals = [residues_matrix[k][i] for k in range(len(self.slots))]
            val = self.ctx.rns.compose(r_vals)
            result.append(val)
        return result

    def free(self):
        for s in self.slots: self.ctx.free_slot(s)

class RNSContext:
    def __init__(self, N, N_LOG, num_moduli=2):
        self.N = N
        self.N_LOG = N_LOG
        self.emu = logos_emu.Emulator()
        
        primes = generate_primes(N_LOG, num_moduli)
        self.rns = RNSBase(primes)
        self.moduli_params = [] # (q, mu, n_inv, twiddle_host_addr)
        
        # Reserve memory for Twiddles
        # Addr 0x10000000 (safe high offset)
        self.twiddle_base_addr = 0x10000000 
        
        for i, q in enumerate(primes):
            mu = (1 << 64) // q
            n_inv = pow(N, -1, q)
            
            # Generate and Upload Twiddles
            twiddles = generate_twiddles(N_LOG, q)
            w_addr = self.twiddle_base_addr + (i * 2 * N * 8) # 8 bytes per word
            # Write to Host RAM immediately
            # Note: write_ram takes word-address (uint64 index), so divide byte offset by 8
            w_word_idx = self.twiddle_base_addr // 8 + (i * 2 * N)
            
            self.emu.write_ram(w_word_idx, twiddles)
            
            self.moduli_params.append({
                'q': q, 'mu': mu, 'n_inv': n_inv, 
                'w_addr': w_word_idx
            })
            
        self.slots_available = [True, True, True, True] 
        self.current_mod_idx = -1

    def switch_context(self, mod_idx):
        if self.current_mod_idx == mod_idx: return
        
        params = self.moduli_params[mod_idx]
        # 1. Set Registers
        self.emu.set_context(params['q'], params['mu'], params['n_inv'])
        
        # 2. Load Twiddles (Host -> Device w_mem)
        # This is a DMA operation via Command Processor
        self.emu.push_load_w_op(params['w_addr'])
        self.emu.push_halt()
        self.emu.run()
        self.emu.reset_state()
        
        self.current_mod_idx = mod_idx

    def alloc_slot(self):
        for i, is_free in enumerate(self.slots_available):
            if is_free:
                self.slots_available[i] = False
                return i
        raise RuntimeError("Out of Device Memory")

    def free_slot(self, idx):
        self.slots_available[idx] = True

    def _bit_reverse(self, arr):
        n = len(arr)
        result = [0] * n
        for i in range(n):
            rev = 0
            temp = i
            for _ in range(self.N_LOG):
                rev = (rev << 1) | (temp & 1)
                temp >>= 1
            result[rev] = arr[i]
        return result

    def upload(self, bigint_vec):
        if len(bigint_vec) != self.N: raise ValueError("Size mismatch")
        assigned_slots = []
        
        for k in range(len(self.rns.moduli)):
            slot_id = self.alloc_slot()
            assigned_slots.append(slot_id)
            
            residue_vec = [x % self.rns.moduli[k] for x in bigint_vec]
            rev_data = self._bit_reverse(residue_vec)
            
            host_addr = slot_id * self.N
            self.emu.write_ram(host_addr, rev_data)
            
            self.emu.push_load_op(slot_id, host_addr)
            self.emu.push_halt()
            self.emu.run()
            self.emu.reset_state()
            
        return RNSVector(self, assigned_slots, self.N)
