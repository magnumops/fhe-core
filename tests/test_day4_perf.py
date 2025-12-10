import sys
import logos_emu
from logos_sdk import RNSContext, LogosProfiler

def test_perf_counters():
    print("[TEST] Initializing...")
    N = 4096
    ctx = RNSContext(N, 12, num_moduli=1)
    profiler = LogosProfiler(ctx)

    print("[TEST] Running Baseline (Idle)...")
    # Просто несколько ресетов
    for _ in range(5): ctx.emu.reset_state()
    
    # Захват
    stats = profiler.capture()
    print(f"Baseline: {stats}")
    if stats['total_cycles'] == 0:
        print("[FAIL] Total cycles is 0!")
        exit(1)

    print("[TEST] Running Workload (NTT)...")
    vec = ctx.upload([1]*N) # Это вызовет LOAD операции
    vec.ntt()               # Это вызовет NTT операции
    
    stats = profiler.capture()
    print(f"Workload: {stats}")
    
    if stats['ntt_ops'] == 0:
        print("[FAIL] NTT ops counter is 0!")
        exit(1)
        
    print(f"[PASS] Performance Counters working. Utilization: {stats['utilization']:.2%}")

if __name__ == "__main__":
    test_perf_counters()
