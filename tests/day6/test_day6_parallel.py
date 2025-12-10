import sys
sys.path.append("/app/build")
try:
    import logos_emu
    import logos_sdk
except ImportError:
    print("[FAIL] Import error")
    sys.exit(1)

def test_parallel_sync():
    print("--- Phase 6 Day 6: Parallel Synchronization Test ---")
    driver = logos_sdk.LogosDriver(logos_emu)
    
    # 1. Init RAM
    for i in range(100): driver.write_ram(0x1000 + i*8, 0xAA)
    for i in range(100): driver.write_ram(0x2000 + i*8, 0xBB)
    for i in range(100): driver.write_ram(0x10000 + i*8, 1) # Shared Twiddles

    print("[INFO] Loading Contexts (Parallel Attempt)...")
    
    # Запускаем загрузку данных для Core 0
    driver.load_data(core_id=0, slot=0, addr=0x1000)
    
    # НЕ ЖДЕМ полного завершения, сразу пускаем Core 1
    # Пусть они дерутся за шину. Арбитр должен разрулить.
    driver.run_cycles(100) 
    
    driver.load_data(core_id=1, slot=0, addr=0x2000)
    
    # Ждем завершения обоих (2 * 20k циклов макс, если последовательно)
    print("[INFO] Waiting for Data Load (Stress Test)...")
    driver.run_cycles(60000)
    
    print("[INFO] Loading Twiddles (Parallel Attempt)...")
    driver.load_twiddles(core_id=0, addr=0x10000)
    driver.run_cycles(100)
    driver.load_twiddles(core_id=1, addr=0x10000)
    
    print("[INFO] Waiting for Twiddles (Stress Test)...")
    driver.run_cycles(100000)
    
    print("[INFO] Starting Parallel Execution...")
    driver.run_ntt(core_id=0)
    driver.run_ntt(core_id=1)
    
    driver.run_cycles(20000)
    
    ops0 = driver.get_ops(0)
    ops1 = driver.get_ops(1)
    print(f"[INFO] Ops: C0={ops0}, C1={ops1}")
    
    if ops0 > 0 and ops1 > 0:
        print("[PASS] Synchronization SUCCESS. No Starvation.")
    else:
        print("[FAIL] Starvation detected.")
        sys.exit(1)

if __name__ == "__main__":
    test_parallel_sync()
