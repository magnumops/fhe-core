import sys
import os

# ВАЖНО: Сначала добавляем путь, потом импортируем!
sys.path.append("/app/build")

try:
    import logos_emu
except ImportError as e:
    print(f"❌ Critical Error: {e}")
    sys.exit(1)

def test_burst():
    print("--- Starting Burst Mode Test ---")
    
    # 1. Заполняем память
    print("[1] Filling RAM...")
    # Инициализация симулятора (и памяти) происходит при создании BurstSim,
    # но для py_write_ram нам нужна память уже сейчас.
    # В текущей реализации (dpi_impl.cpp) py_write_ram проверяет g_ram.
    # Поэтому СНАЧАЛА создаем симулятор.
    
    sim = logos_emu.BurstSim()
    
    # Теперь память есть, пишем
    logos_emu.py_write_ram(100, 0xAAAAAAAA)
    logos_emu.py_write_ram(109, 0x99999999) 
    
    # 2. Читаем пачку
    print("[2] Requesting BURST read at addr 100...")
    sim.set_start_addr(100)
    sim.step()
    
    # 3. Проверяем
    d0 = sim.get_data_0()
    d9 = sim.get_data_9()
    
    print(f"[3] Result[0]: {hex(d0)}")
    print(f"[3] Result[9]: {hex(d9)}")
    
    if d0 == 0xAAAAAAAA and d9 == 0x99999999:
        print("✅ SUCCESS: Burst Mode works! Transferred array in 1 call.")
    else:
        print(f"❌ FAIL: Data mismatch. Expected 0xAAAAAAAA/0x99999999, got {hex(d0)}/{hex(d9)}")
        sys.exit(1)

if __name__ == "__main__":
    test_burst()
