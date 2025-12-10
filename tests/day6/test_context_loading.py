import sys
import time
sys.path.append("/app/build")

try:
    import logos_emu
except ImportError:
    print("[FAIL] Could not import logos_emu")
    sys.exit(1)

def make_cmd(op, slot, target, addr):
    # Format: [Op 8][Slot 4][Target 1][Addr 48]
    return (op << 56) | (slot << 52) | (target << 48) | addr

def test_context_load():
    print("--- Phase 6: Context Loading & NTT Verification ---")
    
    # Init Check
    try:
        emu = logos_emu.LogosContext()
        emu.reset()
    except Exception as e:
        print(f"[FAIL] Init crashed: {e}")
        sys.exit(1)
    
    # 1. Инициализация RAM (Dummy Data)
    print("[INFO] Initializing RAM with dummy data...")
    # Записываем 1 во входные данные (Slot 0 source)
    for i in range(100): 
        logos_emu.write_ram(0x1000 + i*8, 1)
        
    # Записываем 1 в Twiddle Factors
    for i in range(100):
        logos_emu.write_ram(0x10000 + i*8, 1)
        
    # 2. Команда: LOAD DATA (Op=0x02) -> Core 0, Slot 0, Addr=0x1000
    print("[INFO] Step 1: Loading Data into Core 0...")
    emu.push_command(make_cmd(0x02, 0, 0, 0x1000))
    emu.run_cycles(2000)
    
    # 3. Команда: LOAD TWIDDLES (Op=0x04) -> Core 0, Addr=0x10000
    print("[INFO] Step 2: Loading Twiddles into Core 0...")
    emu.push_command(make_cmd(0x04, 0, 0, 0x10000))
    emu.run_cycles(4000)
    
    # 4. Команда: EXECUTE NTT (Op=0x10) -> Core 0
    print("[INFO] Step 3: Executing NTT on Core 0...")
    emu.push_command(make_cmd(0x10, 0, 0, 0))
    
    # Ждем выполнения
    emu.run_cycles(2000)
    
    # 5. Проверка счетчика операций
    ops = emu.get_core_ops(0)
    print(f"[INFO] Core 0 Performance Counter: {ops}")
    
    if ops > 0:
        print("[PASS] SUCCESS: Engine active, operations counted.")
    else:
        print("[FAIL] Counter is 0. Engine stalled or reset failed.")
        sys.exit(1)

if __name__ == "__main__":
    test_context_load()
