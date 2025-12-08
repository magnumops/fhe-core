import sys, struct
sys.path.append('build')
import logos_emu

def load_bin_file(filename):
    with open(filename, 'rb') as f:
        content = f.read()
        # Читаем один раз в переменную!
        return list(struct.unpack(f'<{len(content)//8}Q', content))

def test_full_chain():
    print("=== STARTING FULL CHAIN TEST (SQUARE) ===")
    
    try:
        vec_a = load_bin_file("vector_a.bin")
        config = load_bin_file("config_math.bin")
    except FileNotFoundError:
        print("ERROR: Bin files not found.")
        return

    modulus = config[0]
    print(f"[Host] Modulus: {modulus}")
    
    sim = logos_emu.LogosContext()
    sim.reset_state()
    
    SRC_ADDR = 0x1000
    RES_ADDR = 0x8000
    
    # 1. Write Input
    print(f"[Host] Writing {len(vec_a)} words to RAM...")
    for i, val in enumerate(vec_a): logos_emu.write_ram(SRC_ADDR + i*8, val)
    
    # 2. Exec: LOAD -> SQUARE -> STORE
    print("[Host] LOAD...")
    sim.push_command(2, 0, SRC_ADDR, 0)
    for _ in range(5000): sim.tick()
    
    print("[Host] CALC (SQUARE)...")
    sim.push_command(7, 0, 0, 0)
    for _ in range(100): sim.tick()
    
    # 3. Verify
    print("=== VERIFICATION ===")
    errors = 0
    for i, val in enumerate(vec_a):
        expected = (val * val) % modulus
        actual = logos_emu.read_ram(RES_ADDR + i*8)
        if actual != expected:
            print(f"MISMATCH @ {i}: In={val} Exp={expected} Got={actual}")
            errors += 1
            if errors > 5: break
            
    if errors == 0: print(">>> SUCCESS: Full Chain Math Verified!")
    else: print(f">>> FAILURE: {errors} math errors.")

if __name__ == "__main__":
    test_full_chain()
