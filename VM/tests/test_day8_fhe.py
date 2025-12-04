import sys
import os

# ВАЖНО: Сначала путь, потом импорт!
sys.path.append("/app/build")

try:
    import logos_emu
except ImportError as e:
    print(f"❌ Critical Error: {e}")
    sys.exit(1)

def test_fhe():
    print("--- Starting Basic FHE Test (SEAL) ---")
    
    # 1. Инициализация
    print("[1] Initializing FHE Context...")
    logos_emu.fhe_init()
    
    # 2. Шифрование
    val_a = 5
    val_b = 7
    print(f"[2] Encrypting {val_a} and {val_b}...")
    
    c_a = logos_emu.fhe_encrypt(val_a)
    c_b = logos_emu.fhe_encrypt(val_b)
    
    print(f"    Ciphertext size: {len(c_a)} bytes")

    # 3. Гомоморфное сложение
    print("[3] Computing Add(c_a, c_b)...")
    c_res = logos_emu.fhe_add(c_a, c_b)
    
    # 4. Расшифровка
    print("[4] Decrypting result...")
    res = logos_emu.fhe_decrypt(c_res)
    
    print(f"[Result] {res}")
    
    if res == (val_a + val_b):
        print(f"✅ SUCCESS: {val_a} + {val_b} = {res} in Encrypted Domain!")
    else:
        print(f"❌ FAIL: Expected 12, got {res}")
        sys.exit(1)

if __name__ == "__main__":
    test_fhe()
