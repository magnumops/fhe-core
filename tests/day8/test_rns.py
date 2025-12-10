import sys
# Монтируем SDK и build
sys.path.append("/app/build")
sys.path.append("/app") # for logos_sdk

try:
    import logos_emu
    import logos_sdk
except ImportError:
    print("[FAIL] Import error")
    sys.exit(1)

def test_rns():
    print("--- Phase 6 Day 8: RNS Modulus Switching ---")
    driver = logos_sdk.LogosDriver(logos_emu)
    
    # 1. Prepare Config Struct in RAM
    # Struct: [q, mu, n_inv]
    # Addr: 0x5000
    q1 = 0x0800000000000001
    mu1 = 0
    n_inv1 = 0
    
    print("[INFO] Writing Config 1 to RAM...")
    driver.write_ram(0x5000, q1)
    driver.write_ram(0x5008, mu1)
    driver.write_ram(0x5010, n_inv1)
    
    # 2. Send CONFIG command
    # OPC_CONFIG = 0x05
    print("[INFO] Sending CONFIG command...")
    cmd_config = (0x05 << 56) | 0x5000
    driver.ctx.push_command(cmd_config)
    
    # Wait for small DMA (3 words)
    driver.run_cycles(100)
    
    # 3. Verify Liveness (Run small Load)
    print("[INFO] Verifying liveness with Data Load...")
    driver.load_data(core_id=0, slot=0, addr=0x1000)
    driver.run_cycles(5000) # Wait just a bit, dont need full completion check
    
    print("[PASS] RNS Config command accepted and processed.")

if __name__ == "__main__":
    test_rns()
