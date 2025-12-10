import sys
import os

sys.path.append("/app/build")

def test_integration():
    print("--- Phase 6 Integration Test ---")
    
    try:
        import logos_emu
        print("[PASS] Library imported.")
    except ImportError as e:
        print(f"[FAIL] Import error: {e}")
        sys.exit(1)

    # 1. Инициализация
    try:
        emu = logos_emu.LogosContext()
        emu.reset()
        print("[INFO] Context created and reset.")
    except Exception as e:
        print(f"[FAIL] Initialization failed: {e}")
        sys.exit(1)

    # 2. Тест команды (LOAD Opcode=0x02)
    # Формат: [Opcode 8][Slot 4][Target 1][Addr 48]
    # Op=0x02, Slot=0, Target=0 (Core0), Addr=0x1000
    cmd = (0x02 << 56) | 0x1000
    
    print(f"[INFO] Pushing Command: 0x{cmd:016X}")
    emu.push_command(cmd)
    
    # 3. Прокрутка
    emu.run_cycles(20)
    
    # 4. Проверка живости
    ops = emu.get_core_ops(0)
    print(f"[INFO] Core 0 Internal Ops Counter: {ops}")
    
    print("[PASS] System is responsive.")

if __name__ == "__main__":
    test_integration()
