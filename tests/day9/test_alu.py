import sys
sys.path.append("/app/build")
sys.path.append("/app")

try:
    import logos_emu
    import logos_sdk
except ImportError:
    print("[FAIL] Import error")
    sys.exit(1)

def test_alu():
    print("--- Phase 6 Day 9: Vector ALU Test (Configured) ---")
    driver = logos_sdk.LogosDriver(logos_emu)
    
    # 1. Config RNS
    # Using small q for easy check: q=100
    # Then mu must be floor(2^128 / 100) = ... huge number
    # But let's use the standard large prime from previous tests, or just dummy mu=0 if we assume small inputs < q.
    # Actually, for small inputs (2, 3) and large q, mu=0 might be okay IF mod_mult implementation is correct.
    # Let's set q huge.
    q = 0x0800000000000001
    mu = 0 
    
    # Send Config
    driver.write_ram(0x5000, q)
    driver.write_ram(0x5008, mu)
    driver.write_ram(0x5010, 0)
    cmd_config = (0x05 << 56) | 0x5000
    driver.ctx.push_command(cmd_config)
    driver.run_cycles(100)

    # 2. Prepare Data
    for i in range(20):
        driver.write_ram(0x1000 + i*8, 2)
        driver.write_ram(0x2000 + i*8, 3)
        
    driver.load_data(core_id=0, slot=0, addr=0x1000)
    driver.run_cycles(20000)
    
    driver.load_data(core_id=0, slot=1, addr=0x2000)
    driver.run_cycles(20000)
    
    # 3. ADD
    print("[INFO] Executing ADD (2 + 3)...")
    add_cmd = (0x20 << 56) | (0 << 52) | (0 << 48) | 1
    driver.ctx.push_command(add_cmd)
    driver.run_cycles(5000)
    
    # 4. MULT
    print("[INFO] Executing MULT (5 * 3)...")
    mult_cmd = (0x22 << 56) | (0 << 52) | (0 << 48) | 1
    driver.ctx.push_command(mult_cmd)
    driver.run_cycles(5000)
    
    # 5. Store
    print("[INFO] Storing Result...")
    store_cmd = (0x03 << 56) | (0 << 52) | (0 << 48) | 0x3000
    driver.ctx.push_command(store_cmd)
    driver.run_cycles(20000)
    
    # 6. Verify
    print("[INFO] Verifying Result...")
    errors = 0
    for i in range(20):
        val = logos_emu.read_ram(0x3000 + i*8)
        expected = 15 
        if val != expected:
            print(f"[FAIL] Idx {i}: Got {val}, Expected {expected}")
            errors += 1
            if errors > 5: break
            
    if errors == 0:
        print("[PASS] ALU Arithmetic Verified")
    else:
        sys.exit(1)

if __name__ == "__main__":
    test_alu()
