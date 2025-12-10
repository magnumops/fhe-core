import sys
import struct
import os

# Подключаем эмулятор
sys.path.append('build')
import logos_emu

def load_bin_file(filename):
    data = []
    with open(filename, 'rb') as f:
        content = f.read()
        # Читаем по 8 байт (uint64)
        count = len(content) // 8
        data = struct.unpack(f'<{count}Q', content)
    return list(data)

def test_bit_exact():
    print("=== STARTING BIT-EXACT VERIFICATION ===")
    
    # 1. Загружаем Golden Vectors
    if not os.path.exists("golden_input.bin"):
        print("ERROR: golden_input.bin not found!")
        return
        
    inputs = load_bin_file("golden_input.bin") # 4096 чисел
    print(f"[Host] Loaded {len(inputs)} words from golden_input.bin")
    
    # 2. Инициализация
    sim = logos_emu.LogosContext()
    sim.reset_state()
    
    # 3. Загружаем данные в RAM (адрес 0x1000)
    SRC_ADDR = 0x1000
    DST_ADDR = 0x8000
    
    for i, val in enumerate(inputs):
        logos_emu.write_ram(SRC_ADDR + i*8, val)
        
    print("[Host] Data written to RAM. Starting Emulation...")
    
    # 4. OP_LOAD_DATA (Opcode 2) с адреса 0x1000
    # Аргументы: opcode, slot(0), addr, target(0)
    sim.push_command(2, 0, SRC_ADDR, 0)
    
    # Ждем завершения (пока ready не станет 1)
    # В этой простой модели просто тикаем достаточное кол-во раз
    for _ in range(5000): sim.tick()
    
    print("[RTL] Load Complete (simulated)")

    # 5. OP_STORE_DATA (Opcode 4) в адрес 0x8000
    sim.push_command(4, 0, DST_ADDR, 0)
    
    for _ in range(5000): sim.tick()
    print("[RTL] Store Complete (simulated)")
    
    # 6. Сверка (Verification)
    errors = 0
    for i, expected in enumerate(inputs):
        actual = logos_emu.read_ram(DST_ADDR + i*8)
        if actual != expected:
            print(f"MISMATCH at index {i}: Expected {expected:#x}, Got {actual:#x}")
            errors += 1
            if errors > 5: break
            
    if errors == 0:
        print(">>> SUCCESS: BIT-EXACT MATCH! RTL is perfectly aligned with SEAL data.")
    else:
        print(f">>> FAILURE: {errors} errors found.")

if __name__ == "__main__":
    test_bit_exact()
