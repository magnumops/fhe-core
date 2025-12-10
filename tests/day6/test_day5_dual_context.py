import sys
import time
sys.path.append("/app/build")

try:
    import logos_emu
    import logos_sdk
except ImportError:
    print("[FAIL] Import error")
    sys.exit(1)

def test_dual_context_serial():
    print("--- Phase 6 Day 5: Serial Verification (Isolation Test) ---")
    
    driver = logos_sdk.LogosDriver(logos_emu)
    
    # 1. Init RAM
    for i in range(100): driver.write_ram(0x1000 + i*8, 0xAA)
    for i in range(100): driver.write_ram(0x2000 + i*8, 0xBB)
    for i in range(100): driver.write_ram(0x10000 + i*8, 1)

    # --- CORE 0 SEQUENCE ---
    print("\n[INFO] === TESTING CORE 0 ===")
    
    driver.load_data(core_id=0, slot=0, addr=0x1000)
    driver.run_cycles(30000) 
    
    driver.load_twiddles(core_id=0, addr=0x10000)
    driver.run_cycles(100000)
    
    driver.run_ntt(core_id=0)
    driver.run_cycles(10000)
    
    ops0 = driver.get_ops(0)
    print(f"[INFO] Core 0 Finished. Ops: {ops0}")

    # --- CORE 1 SEQUENCE ---
    print("\n[INFO] === TESTING CORE 1 ===")
    # Теперь шина полностью свободна. Если Core 1 не заработает сейчас, оно мертво.
    
    driver.load_data(core_id=1, slot=0, addr=0x2000)
    driver.run_cycles(30000)
    
    driver.load_twiddles(core_id=1, addr=0x10000)
    driver.run_cycles(100000)
    
    driver.run_ntt(core_id=1)
    driver.run_cycles(10000)
    
    ops1 = driver.get_ops(1)
    print(f"[INFO] Core 1 Finished. Ops: {ops1}")
    
    # --- FINAL CHECK ---
    if ops0 > 0 and ops1 > 0:
        print("\n[PASS] Both cores functional in serial mode.")
    else:
        print("\n[FAIL] One of the cores failed.")
        sys.exit(1)

if __name__ == "__main__":
    test_dual_context_serial()
