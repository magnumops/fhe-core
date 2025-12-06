import sys
import os

# Явное добавление пути к собранному модулю
sys.path.append("/app/build")

import logos_emu
import numpy as np

def test_diamond_loop():
    print("=== DIAMOND LOOP TEST (PHASE 7 START) ===")
    
    # 1. Init
    try:
        ctx = logos_emu.LogosContext()
        ctx.reset_state()
        print("[1] Context Initialized")
    except Exception as e:
        print(f"FATAL: Failed to init context: {e}")
        sys.exit(1)

    # 2. Basic Check (чтение регистров)
    # Пока просто проверяем, что ядро живо и отвечает
    try:
        ops0 = ctx.get_core_ops(0)
        print(f"[2] Core 0 Ops Counter: {ops0}")
    except Exception as e:
        print(f"FATAL: Failed to read ops: {e}")
        sys.exit(1)
    
    print("✅ SUCCESS: Environment is ready for Phase 7.")

if __name__ == "__main__":
    test_diamond_loop()
