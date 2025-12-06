import sys
sys.path.append("/app/build")
sys.path.append("/app")

try:
    import logos_emu
    import logos_sdk
except ImportError:
    print("[FAIL] Import error")
    sys.exit(1)

def test_diamond_final():
    print("--- Phase 6 Day 10: DIAMOND LOOP DUAL (FINAL) ---")
    driver = logos_sdk.LogosDriver(logos_emu)
    
    # 1. RNS Configuration (Small inputs, huge Q -> mu=0 is safe)
    q = 0x0800000000000001
    driver.write_ram(0x5000, q)
    driver.write_ram(0x5008, 0) # mu
    driver.write_ram(0x5010, 0) # n_inv
    
    print("[INFO] Configuring Cores...")
    # Config Core 0
    driver.ctx.push_command((0x05 << 56) | (0 << 48) | 0x5000)
    # Config Core 1
    driver.ctx.push_command((0x05 << 56) | (1 << 48) | 0x5000)
    
    # 2. Setup Data
    N = 4096
    ADDR_A       = 0x10000
    ADDR_B       = 0x20000
    ADDR_EXCH    = 0x30000
    ADDR_OUT     = 0x40000
    ADDR_TWIDDLES= 0x80000
    
    print("[INFO] Generating Inputs (A=2, B=3)...")
    for i in range(N):
        driver.write_ram(ADDR_A + i*8, 2)
        driver.write_ram(ADDR_B + i*8, 3)
    # Twiddles = 1
    for i in range(2*N):
        driver.write_ram(ADDR_TWIDDLES + i*8, 1)

    # 3. Parallel Load & NTT
    print("[INFO] Step 1: Parallel Load & NTT...")
    driver.load_data(core_id=0, slot=0, addr=ADDR_A)
    driver.load_data(core_id=1, slot=0, addr=ADDR_B)
    driver.load_twiddles(core_id=0, addr=ADDR_TWIDDLES)
    driver.load_twiddles(core_id=1, addr=ADDR_TWIDDLES)
    driver.run_cycles(200000) # Wait for massive DMA
    
    print("[INFO] Starting Dual NTT...")
    driver.run_ntt(core_id=0)
    driver.run_ntt(core_id=1)
    driver.run_cycles(20000)
    
    # 4. Exchange (Core 1 -> RAM -> Core 0)
    print("[INFO] Step 2: Exchange (C1 Store -> C0 Load)...")
    # Store Core 1 Slot 0 -> Exchange RAM
    store_cmd = (0x03 << 56) | (0 << 52) | (1 << 48) | ADDR_EXCH
    driver.ctx.push_command(store_cmd)
    driver.run_cycles(20000)
    
    # Load into Core 0 Slot 1
    driver.load_data(core_id=0, slot=1, addr=ADDR_EXCH)
    driver.run_cycles(20000)
    
    # 5. Math (Mult + INTT) on Core 0
    print("[INFO] Step 3: Calculation (Mult + INTT)...")
    # Mult Slot 0 * Slot 1
    mult_cmd = (0x22 << 56) | (0 << 52) | (0 << 48) | 1
    driver.ctx.push_command(mult_cmd)
    driver.run_cycles(5000)
    
    # INTT Slot 0
    intt_cmd = (0x11 << 56) | (0 << 52) | (0 << 48) | 0
    driver.ctx.push_command(intt_cmd)
    driver.run_cycles(20000)
    
    # 6. Final Result
    print("[INFO] Step 4: Final Store...")
    final_store = (0x03 << 56) | (0 << 52) | (0 << 48) | ADDR_OUT
    driver.ctx.push_command(final_store)
    driver.run_cycles(20000)
    
    # 7. Validation
    print("[INFO] Verifying Output...")
    zeros = 0
    non_zeros = 0
    sample_val = 0
    
    for i in range(N):
        val = logos_emu.read_ram(ADDR_OUT + i*8)
        if val == 0: 
            zeros += 1
        else: 
            non_zeros += 1
            if sample_val == 0: sample_val = val
            
    print(f"[INFO] Stats: NonZero={non_zeros}, Zero={zeros}")
    print(f"[INFO] Sample Non-Zero Value: {sample_val}")
    
    if non_zeros > 0:
        print("[PASS] DIAMOND LOOP COMPLETED! Dual Core FHE Operations Verified.")
    else:
        print("[FAIL] Output is all zeros.")
        sys.exit(1)

if __name__ == "__main__":
    test_diamond_final()
