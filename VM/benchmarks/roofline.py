import sys
import math
sys.path.append("/app/src/python")
from logos_sdk import RNSContext, LogosProfiler

def roofline_report():
    print("\n=== LOGOS ROOFLINE ANALYSIS ===")
    N = 4096
    N_LOG = 12
    ctx = RNSContext(N, N_LOG, num_moduli=1)
    profiler = LogosProfiler(ctx)
    
    # --- Theoretical Limits ---
    # ALU: 1 op per cycle per element (Single Issue)
    theo_cycles_alu = N
    # NTT: (N/2) * log2(N) butterflies. Each BF is 1 op in our pipeline logic.
    theo_cycles_ntt = (N // 2) * N_LOG
    
    print(f"Hardware Params: N={N}, Pipeline Width=1")
    print(f"Theoretical Limits: ALU={theo_cycles_alu}, NTT={theo_cycles_ntt} cycles")
    print("-" * 60)
    print(f"{'Operation':<10} | {'Actual':<10} | {'Theoret':<10} | {'Eff %':<10} | {'Ops/Cyc':<10}")
    print("-" * 60)

    # 1. Measure ADD
    vec_a = ctx.upload([i for i in range(N)])
    vec_b = ctx.upload([i for i in range(N)])
    ctx.emu.reset_state()
    
    start = profiler.capture()
    vec_a.add(vec_b)
    end = profiler.capture()
    
    cycles_add = end['total_cycles'] - start['total_cycles']
    eff_add = (theo_cycles_alu / cycles_add) * 100
    ipc_add = N / cycles_add
    print(f"{'ADD':<10} | {cycles_add:<10} | {theo_cycles_alu:<10} | {eff_add:<10.2f} | {ipc_add:<10.2f}")

    # 2. Measure MULT
    start = profiler.capture()
    vec_a.mul(vec_b)
    end = profiler.capture()
    
    cycles_mul = end['total_cycles'] - start['total_cycles']
    eff_mul = (theo_cycles_alu / cycles_mul) * 100
    ipc_mul = N / cycles_mul
    print(f"{'MULT':<10} | {cycles_mul:<10} | {theo_cycles_alu:<10} | {eff_mul:<10.2f} | {ipc_mul:<10.2f}")

    # 3. Measure NTT
    start = profiler.capture()
    vec_a.ntt()
    end = profiler.capture()
    
    cycles_ntt = end['total_cycles'] - start['total_cycles']
    # For NTT, Ops count is number of butterflies
    ops_count = theo_cycles_ntt 
    eff_ntt = (theo_cycles_ntt / cycles_ntt) * 100
    ipc_ntt = ops_count / cycles_ntt
    print(f"{'NTT':<10} | {cycles_ntt:<10} | {theo_cycles_ntt:<10} | {eff_ntt:<10.2f} | {ipc_ntt:<10.2f}")
    
    print("-" * 60)
    if eff_ntt > 99.0 and eff_add > 99.0:
        print("[CONCLUSION] Architecture is Compute-Bound (Optimal).")
    else:
        print("[CONCLUSION] Architecture is Memory/Latency Bound.")

if __name__ == "__main__":
    roofline_report()
