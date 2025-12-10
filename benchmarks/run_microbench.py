import sys
import os
# Hack to find SDK
sys.path.append("/app/src/python")
from logos_sdk import RNSContext, LogosProfiler

def run_bench():
    print("=== LOGOS MICRO-BENCHMARK v1.0 ===")
    N = 4096
    ctx = RNSContext(N, 12, num_moduli=1)
    profiler = LogosProfiler(ctx)
    
    # 1. Warmup
    print("State: Warming up...")
    vec_a = ctx.upload([i for i in range(N)])
    vec_b = ctx.upload([2*i for i in range(N)])
    ctx.emu.reset_state()
    
    # 2. Benchmark NTT
    print("State: Benchmarking NTT...")
    profiler.capture() # Reset counters snapshot (capture reads current, next capture diffs)
    # Note: Our simple profiler currently returns absolute counters. 
    # To measure a specific block, we need to read before and after, or just rely on reset_state NOT resetting counters (which we did!)
    # Wait, we made counters PERSISTENT. So we need to take a snapshot manually.
    
    start_stats = profiler.capture()
    vec_a.ntt()
    end_stats = profiler.capture()
    
    delta_cycles = end_stats['total_cycles'] - start_stats['total_cycles']
    delta_ntt = end_stats['ntt_ops'] - start_stats['ntt_ops']
    print(f"-> NTT: {delta_cycles} cycles (Ops: {delta_ntt})")

    # 3. Benchmark Vector Add
    print("State: Benchmarking ADD...")
    start_stats = profiler.capture()
    vec_a.add(vec_b)
    end_stats = profiler.capture()
    
    delta_cycles = end_stats['total_cycles'] - start_stats['total_cycles']
    delta_alu = end_stats['alu_ops'] - start_stats['alu_ops']
    print(f"-> ADD: {delta_cycles} cycles (Ops: {delta_alu})")
    
    # 4. Benchmark Vector Mult
    print("State: Benchmarking MULT...")
    start_stats = profiler.capture()
    vec_a.mul(vec_b)
    end_stats = profiler.capture()
    
    delta_cycles = end_stats['total_cycles'] - start_stats['total_cycles']
    delta_alu = end_stats['alu_ops'] - start_stats['alu_ops']
    print(f"-> MULT: {delta_cycles} cycles (Ops: {delta_alu})")

    print("=== BENCHMARK COMPLETE ===")

if __name__ == "__main__":
    run_bench()
