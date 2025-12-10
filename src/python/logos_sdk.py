import sys
import os
import logos_emu
try:
    from rns_math import RNSBase, generate_primes, generate_twiddles
except ImportError:
    # Fallback if running from a different dir structure
    sys.path.append(os.path.dirname(__file__))
    from rns_math import RNSBase, generate_primes, generate_twiddles

# --- PHASE 4: DEBUG TOOLS ---

class TraceGuard:
    """
    Context manager for Smart Tracing.
    Auto-saves VCD only on crash.
    """
    def __init__(self, emu, test_name):
        self.emu = emu
        self.name = test_name
        self.tmp_file = f"trace_{test_name}.tmp.vcd"
        self.final_file = f"ERROR_{test_name}.vcd"

    def __enter__(self):
        if os.path.exists(self.tmp_file): os.remove(self.tmp_file)
        if os.path.exists(self.final_file): os.remove(self.final_file)
        # Check if start_trace exists (it might not on old C++ builds)
        if hasattr(self.emu, 'start_trace'):
            self.emu.start_trace(self.tmp_file)
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        if hasattr(self.emu, 'stop_trace'):
            self.emu.stop_trace()
        
        if exc_type:
            print(f"\n[TRACE-GUARD] 🚨 EXCEPTION! Saving dump -> {self.final_file}")
            if os.path.exists(self.tmp_file):
                os.rename(self.tmp_file, self.final_file)
        else:
            if os.path.exists(self.tmp_file):
                os.remove(self.tmp_file)
        return False

class LogosProfiler:
    """
    Hardware Performance Counter Interface.
    """
    def __init__(self, ctx):
        self.ctx = ctx
        self.stats_addr = 0x20000000 # Reserved RAM area for stats

    def capture(self):
        # 1. Send Read Perf Command
        if hasattr(self.ctx.emu, 'push_read_perf_op'):
            self.ctx.emu.push_read_perf_op(self.stats_addr)
        else:
            print("[WARN] Emulator does not support HPC (push_read_perf_op missing)")
            return {'total_cycles': 0, 'utilization': 0.0}

        self.ctx.emu.push_halt()
        self.ctx.emu.run()
        self.ctx.emu.reset_state()

        # 2. Read 4 words: [Total, Active, NTT, ALU]
        data = self.ctx.emu.read_ram(self.stats_addr, 4)
        
        stats = {
            'total_cycles': data[0],
            'active_cycles': data[1],
            'ntt_ops': data[2],
            'alu_ops': data[3]
        }
        
        if stats['total_cycles'] > 0:
            stats['utilization'] = stats['active_cycles'] / stats['total_cycles']
        else:
            stats['utilization'] = 0.0
            
        return stats

# --- PHASE 3: CORE LOGIC ---

OPC_ADD  = 0x20
OPC_SUB  = 0x21
OPC_MULT = 0x22

class RNSVector:
    def __init__(self, ctx, slots, size):
        self.ctx = ctx
        self.slots = slots
        self.size = size

    def ntt(self):
        for i, slot_id in enumerate(self.slots):
            self.ctx.switch_context(i)
            self.ctx.emu.push_ntt_op(slot_id, 0)
            self.ctx.emu.push_halt()
            self.ctx.emu.run()
            self.ctx.emu.reset_state()
        return self

    def intt(self):
        for i, slot_id in enumerate(self.slots):
            self.ctx.switch_context(i)
            host_addr = slot_id * self.size
            self.ctx.emu.push_store_op(slot_id, host_addr)
            self.ctx.emu.push_halt()
            self.ctx.emu.run()
            self.ctx.emu.reset_state()

            data = self.ctx.emu.read_ram(host_addr, self.size)
            rev_data = self.ctx._bit_reverse(data)
            self.ctx.emu.write_ram(host_addr, rev_data)
            self.ctx.emu.push_load_op(slot_id, host_addr)

            self.ctx.emu.push_ntt_op(slot_id, 1) 
            self.ctx.emu.push_halt()
            self.ctx.emu.run()
            self.ctx.emu.reset_state()
        return self

    def add(self, other):
        if len(self.slots) != len(other.slots): raise ValueError("RNS base mismatch")
        for i, (tgt, src) in enumerate(zip(self.slots, other.slots)):
            self.ctx.switch_context(i)
            self.ctx.emu.push_alu_op(OPC_ADD, tgt, src)
            self.ctx.emu.push_halt()
            self.ctx.emu.run()
            self.ctx.emu.reset_state()
        return self

    def mul(self, other):
        if len(self.slots) != len(other.slots): raise ValueError("RNS base mismatch")
        for i, (tgt, src) in enumerate(zip(self.slots, other.slots)):
            self.ctx.switch_context(i)
            self.ctx.emu.push_alu_op(OPC_MULT, tgt, src)
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
        self.moduli_params = []
        self.twiddle_base_addr = 0x10000000

        for i, q in enumerate(primes):
            mu = (1 << 64) // q
            n_inv = pow(N, -1, q)
            twiddles = generate_twiddles(N_LOG, q)
            w_word_idx = self.twiddle_base_addr // 8 + (i * 2 * N)

            self.emu.write_ram(w_word_idx, twiddles)
            self.moduli_params.append({
                'q': q, 'mu': mu, 'n_inv': n_inv, 'w_addr': w_word_idx
            })

        self.slots_available = [True, True, True, True]
        self.current_mod_idx = -1

    def switch_context(self, mod_idx):
        if self.current_mod_idx == mod_idx: return
        params = self.moduli_params[mod_idx]
        self.emu.set_context(params['q'], params['mu'], params['n_inv'])
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
