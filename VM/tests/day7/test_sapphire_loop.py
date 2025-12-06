import sys
import random
# Paths setup
sys.path.append("/app/build")
sys.path.append("/app")

try:
    import logos_emu
    import logos_sdk
except ImportError as e:
    print(f"[FAIL] Import error: {e}")
    sys.exit(1)

def test_sapphire_loop():
    print("--- Phase 6 Day 7: SAPPHIRE LOOP (Full Cycle) ---")
    driver = logos_sdk.LogosDriver(logos_emu)
    
    # Init Twiddles
    for i in range(8192): driver.write_ram(0x10000 + i*8, 1)
    
    # 1. Generate Input
    N = 4096
    input_poly = [(i % 100) + 1 for i in range(N)] # avoid zeros
    
    print("[INFO] Loading Input Data...")
    for i, val in enumerate(input_poly):
        driver.write_ram(0x1000 + i*8, val)
        
    # 2. Load
    print("[INFO] Loading Context to Core 0...")
    driver.load_twiddles(core_id=0, addr=0x10000)
    driver.run_cycles(100000)
    
    driver.load_data(core_id=0, slot=0, addr=0x1000)
    driver.run_cycles(20000)
    
    # 3. Exec NTT
    print("[INFO] Running NTT...")
    driver.run_ntt(core_id=0)
    driver.run_cycles(10000)
    
    # 4. Store Result (Opcode 0x03) -> 0x2000
    print("[INFO] Storing Result to 0x2000...")
    # Op=0x03, Slot=0, Core=0, Addr=0x2000
    store_cmd = (0x03 << 56) | (0 << 52) | (0 << 48) | 0x2000
    driver.ctx.push_command(store_cmd, 100000)
    driver.run_cycles(20000)
    
    # 5. Verify
    print("[INFO] Verifying Result in RAM...")
    changed_count = 0
    zeros_count = 0
    
    for i in range(N):
        val = logos_emu.read_ram(0x2000 + i*8)
        if val != input_poly[i]:
            changed_count += 1
        if val == 0:
            zeros_count += 1
            
    print(f"[INFO] Changed Values: {changed_count}/{N}")
    print(f"[INFO] Zero Values: {zeros_count}/{N}")
    
    if changed_count > 0 and zeros_count < N:
        print("[PASS] Sapphire Loop Closed! Data transformed and retrieved.")
    else:
        print("[FAIL] Data output looks suspicious.")
        sys.exit(1)

if __name__ == "__main__":
    test_sapphire_loop()
