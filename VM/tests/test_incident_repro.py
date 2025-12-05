import sys
import logos_emu
sys.path.append("/app/build")

def test_interleaved():
    print("=== TEST: Parallel Execution (Interleaved) ===")
    
    ctx = logos_emu.LogosContext()
    
    print("Step 1: Resetting state BEFORE dispatching...")
    ctx.reset_state()
    
    print("Step 2: Dispatching Interleaved Tasks (A -> B -> A -> B)...")
    # 4 задачи: 2 для Ядра 0, 2 для Ядра 1
    ctx.push_ntt_op(0, 0)
    ctx.push_ntt_op(1, 1)
    ctx.push_ntt_op(0, 0)
    ctx.push_ntt_op(1, 1)
    
    # Важно: отправляем HALT, чтобы не было Timeout
    ctx.push_halt()
    
    print("Step 3: Running...")
    ctx.run()
    
    print("Step 4: Checking Counters...")
    
    # Читаем счетчики из железа
    ops0 = ctx.get_core_ops(0)
    ops1 = ctx.get_core_ops(1)
    
    # Форматируем вывод как на скриншоте
    # (Active cycles эмулируем как ops * 5, так как Mock Core тратит 5 тактов на задачу)
    print(f"Core 0: Total={ops0}, Active={ops0*5}, Ops={ops0}")
    print(f"Core 1: Total={ops1}, Active={ops1*5}, Ops={ops1}")
    
    if ops0 == 2 and ops1 == 2:
        print("[PASS] Operation count match (Expected 2 each).")
        print("✅ VICTORY: SYSTEM IS ALIVE.")
    else:
        print(f"[FAIL] Operation count mismatch (Expected 2 each).")
        sys.exit(1)

if __name__ == "__main__":
    test_interleaved()
