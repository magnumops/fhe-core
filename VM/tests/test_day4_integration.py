import sys
import os

# Путь к библиотеке
sys.path.append("/app/build")

try:
    import logos_emu
    print("✅ SUCCESS: Module 'logos_emu' imported.")
except ImportError as e:
    print(f"❌ FAIL: Could not import 'logos_emu'. Error: {e}")
    sys.exit(1)

def test_counter():
    print("--- Starting Integration Test ---")
    
    # 1. Инстанцируем симулятор
    sim = logos_emu.CounterSim()
    print("✅ Simulator Instantiated")

    # 2. Сброс
    sim.reset_device()
    val = sim.get_count()
    if val != 0:
        print(f"❌ FAIL: Reset failed. Expected 0, got {val}")
        sys.exit(1)
    print("✅ Reset OK")

    # 3. Шагаем (Tick-Tock)
    # Счетчик увеличивается на каждом такте
    for i in range(1, 6):
        sim.step()
        val = sim.get_count()
        print(f"Step {i}: Count = {val}")
        
        if val != i:
             print(f"❌ FAIL: At step {i} expected {i}, got {val}")
             sys.exit(1)

    print("🎉 Day 4 Complete: Python fully controls Verilog hardware!")

if __name__ == "__main__":
    test_counter()
