import sys
import random
import time

sys.path.append("/app/build")
sys.path.append("/app")

try:
    import logos_emu
    import logos_sdk
except ImportError:
    print("[FAIL] Import error")
    sys.exit(1)

def test_diamond_dual():
    print("--- Phase 6 Day 10: DIAMOND LOOP DUAL (Diagnostic) ---")
    driver = logos_sdk.LogosDriver(logos_emu)
    
    # RNS Config
    q = 0x0800000000000001
    driver.write_ram(0x5000, q)
    driver.write_ram(0x5008, 0)
    driver.write_ram(0x5010, 0)
    
    print("[INFO] Config Core 0...")
    driver.ctx.push_command((0x05 << 56) | (0 << 48) | 0x5000) 
    print("[INFO] Config Core 1...")
    driver.ctx.push_command((0x05 << 56) | (1 << 48) | 0x5000) 
    
    N = 4096
    ADDR_A       = 0x10000  
    ADDR_B       = 0x20000 
    
    print("[INFO] Generating Vectors...")
    for i in range(N):
        driver.write_ram(ADDR_A + i*8, 2) 
        driver.write_ram(ADDR_B + i*8, 3)
    
    # Check RAM before load
    val_b = logos_emu.read_ram(ADDR_B)
    print(f"[DEBUG] RAM[0x20000] before load = {val_b}")
    
    print("[INFO] Step 1: Parallel Load...")
    driver.load_data(core_id=0, slot=0, addr=ADDR_A)
    driver.load_data(core_id=1, slot=0, addr=ADDR_B)
    driver.run_cycles(50000) 
    
    print("[INFO] Step 2: Store Test (Core 1 Direct Store)...")
    # Immediate store back to see if data was loaded
    store_cmd = (0x03 << 56) | (0 << 52) | (1 << 48) | 0x30000
    driver.ctx.push_command(store_cmd)
    driver.run_cycles(20000)
    
    val_out = logos_emu.read_ram(0x30000)
    print(f"[DEBUG] RAM[0x30000] after store = {val_out}")
    
    if val_out == 3:
        print("[PASS] Core 1 Loopback (Load->Store) Works!")
    else:
        print("[FAIL] Core 1 Loopback Failed.")
        sys.exit(1)

if __name__ == "__main__":
    test_diamond_dual()
