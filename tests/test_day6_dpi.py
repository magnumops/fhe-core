import sys
import os

sys.path.append("/app/build")

try:
    import logos_emu
except ImportError as e:
    print(f"❌ Critical Error: {e}")
    sys.exit(1)

def test_dpi():
    print("--- Starting DPI Memory Test ---")
    
    # 1. Сначала создаем симулятор! 
    # Это вызовет init_ram() в C++ и выделит память.
    print("[1] Instantiating Simulator...")
    sim = logos_emu.MemorySim()

    # 2. Теперь память существует, можно писать
    print("[2] Python Writing 0xCAFEBABE to addr 10")
    logos_emu.py_write_ram(10, 0xCAFEBABE)
    
    # 3. Говорим Verilog'у читать
    print("[3] Verilog Requesting addr 10...")
    sim.set_addr(10)
    sim.step() 
    
    # 4. Проверяем
    val = sim.get_data()
    print(f"[4] Result: {hex(val)}")
    
    if val == 0xCAFEBABE:
        print("✅ SUCCESS: DPI Bridge works! Python -> RAM -> DPI -> Verilog")
    else:
        print(f"❌ FAIL: Expected 0xCAFEBABE, got {hex(val)}")
        sys.exit(1)

if __name__ == "__main__":
    test_dpi()
