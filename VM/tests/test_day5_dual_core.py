import sys
import logos_emu
from logos_sdk import RNSContext, LogosProfiler

def test_dual_core():
    print("=== TEST: Dual Core Activation ===")
    N = 4096
    ctx = RNSContext(N, 12, num_moduli=1)
    
    # 1. Run on Core 0
    print("Step 1: Running on Core 0...")
    ctx.emu.set_target_core(0)
    # Upload & NTT on Core 0
    vec_a = ctx.upload([1]*N)
    vec_a.ntt()
    
    # Check Perf Counters Core 0
    ctx.emu.push_read_perf_op(0x20000000)
    ctx.emu.push_halt()
    ctx.emu.run()
    ctx.emu.reset_state()
    stats0 = ctx.emu.read_ram(0x20000000, 4)
    print(f"Core 0 Stats: NTT Ops={stats0[2]}")
    if stats0[2] == 0:
        print("FAIL: Core 0 did not execute.")
        exit(1)

    # 2. Run on Core 1
    print("Step 2: Running on Core 1...")
    ctx.emu.set_target_core(1)
    # Upload & NTT on Core 1 (Note: upload loads w_mem for Core 1 too if we re-run setup, 
    # but ctx setup only loaded w_mem for Core 0 effectively if we didn't broadcast.
    # Wait, w_mem load is also core-specific now!
    # We need to load twiddles for Core 1 explicitly.
    print("   -> Loading Twiddles for Core 1...")
    # Load W from host address (stored in context)
    w_addr = ctx.moduli_params[0]['w_addr']
    ctx.emu.push_load_w_op(w_addr)
    
    vec_b = ctx.upload([2]*N)
    vec_b.ntt()
    
    # Check Perf Counters Core 1
    # We use a DIFFERENT address for Core 1 dump to verify separation
    ctx.emu.push_read_perf_op(0x30000000)
    ctx.emu.push_halt()
    ctx.emu.run()
    ctx.emu.reset_state()
    stats1 = ctx.emu.read_ram(0x30000000, 4)
    print(f"Core 1 Stats: NTT Ops={stats1[2]}")
    
    if stats1[2] == 0:
        print("FAIL: Core 1 did not execute.")
        exit(1)
        
    print("PASS: Both cores executed tasks successfully.")

if __name__ == "__main__":
    test_dual_core()
