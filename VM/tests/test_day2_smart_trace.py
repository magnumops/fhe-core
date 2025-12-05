import sys
import os
# Добавляем путь к SDK
sys.path.append("/app/src/python")
import logos_emu
from logos_sdk import TraceGuard

def test_smart_triggers():
    emu = logos_emu.Emulator()
    
    # Сценарий 1: Успешный тест (Файл должен исчезнуть)
    print("\n--- Scenario 1: Success (No Trace) ---")
    with TraceGuard(emu, "success_case"):
        emu.reset_state()
        # Симулируем работу
        for _ in range(10): emu.reset_state()
    
    if os.path.exists("ERROR_success_case.vcd") or os.path.exists("trace_success_case.tmp.vcd"):
        print("[FAIL] Trace file persisted after success!")
        exit(1)
    else:
        print("[PASS] Trace cleaned up correctly.")

    # Сценарий 2: Авария (Файл должен сохраниться)
    print("\n--- Scenario 2: Crash Simulation (Trace Expected) ---")
    try:
        with TraceGuard(emu, "crash_case"):
            emu.reset_state()
            print("Simulating critical failure...")
            raise RuntimeError("Simulation Explosion!")
    except RuntimeError:
        pass # Мы ожидали ошибку

    expected_file = "ERROR_crash_case.vcd"
    if os.path.exists(expected_file):
        size = os.path.getsize(expected_file)
        print(f"[PASS] Crash dump saved: {expected_file} ({size} bytes)")
    else:
        print(f"[FAIL] Crash dump NOT found!")
        exit(1)

if __name__ == "__main__":
    test_smart_triggers()
