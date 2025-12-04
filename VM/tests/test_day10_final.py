import sys
import struct
import logos_emu

sys.path.append("/app/build")

def test_golden_loop():
    print("--- Starting GOLDEN LOOP Test ---")
    
    # 1. Инициализация
    logos_emu.fhe_init()
    sim = logos_emu.CopySim()
    
    # 2. Шифруем данные (Число 1337)
    secret_val = 1337
    print(f"[1] Encrypting {secret_val}...")
    # Получаем bytes object
    ct_bytes = logos_emu.fhe_encrypt(secret_val)
    print(f"    Ciphertext size: {len(ct_bytes)} bytes")
    
    # 3. Загружаем шифртекст в память (адрес 0x1000)
    # Нам нужно превратить bytes в array of uint64 для записи
    # Добиваем нулями до кратности 8 байт
    pad_len = (8 - len(ct_bytes) % 8) % 8
    ct_padded = ct_bytes + b'\x00' * pad_len
    
    # Распаковываем в uint64 (little endian)
    u64_array = []
    for i in range(0, len(ct_padded), 8):
        val = struct.unpack("<Q", ct_padded[i:i+8])[0]
        u64_array.append(val)
    
    SRC_ADDR = 0x100 # Смещение в словах (uint64)
    DST_ADDR = 0x500 # Смещение назначения
    
    print(f"[2] Uploading {len(u64_array)} words to RAM at offset {SRC_ADDR}...")
    for i, word in enumerate(u64_array):
        logos_emu.py_write_ram(SRC_ADDR + i, word)

    # 4. Запускаем "Аппаратный Копир" (Verilog)
    print(f"[3] Starting Hardware Copy Engine: {SRC_ADDR} -> {DST_ADDR}...")
    sim.start_copy(SRC_ADDR, DST_ADDR)
    
    # Ждем завершения (максимум 100 тактов)
    ticks = 0
    while not sim.is_done() and ticks < 100:
        sim.step()
        ticks += 1
    
    if ticks >= 100:
        print("❌ FAIL: Hardware Timeout")
        sys.exit(1)
        
    print(f"    Hardware finished in {ticks} ticks.")
    
    # 5. Выгружаем результат из памяти (адрес 0x2000 / offset 0x500)
    print("[4] Downloading result from RAM...")
    res_bytes = bytearray()
    for i in range(len(u64_array)):
        val = logos_emu.py_read_ram(DST_ADDR + i)
        res_bytes.extend(struct.pack("<Q", val))
    
    # Обрезаем паддинг (SEAL сам разберется, но лучше вернуть как было)
    # SEAL при load() читает сколько надо.
    
    # 6. Расшифровка
    print("[5] Decrypting result...")
    try:
        decrypted = logos_emu.fhe_decrypt(bytes(res_bytes))
        print(f"[Result] {decrypted}")
        
        if decrypted == secret_val:
            print("🎉 GRAND FINALE: Success! Data survived the round trip!")
            print("Python -> FHE -> RAM -> Verilog -> RAM -> FHE -> Python")
        else:
            print(f"❌ FAIL: Expected {secret_val}, got {decrypted}")
            sys.exit(1)
    except Exception as e:
        print(f"❌ FAIL: Decryption crashed. Data corrupted? {e}")
        sys.exit(1)

if __name__ == "__main__":
    test_golden_loop()
