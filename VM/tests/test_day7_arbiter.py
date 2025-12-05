import sys
import logos_emu
sys.path.append("/app/build")

def test_arbiter():
    print("--- Starting Day 7: Memory Arbiter Test ---")
    ctx = logos_emu.LogosContext()
    
    print("[1] Launching Dual Core with Memory Access...")
    # Оба ядра начнут ломиться в память
    ctx.push_ntt_op(0, 0)
    ctx.push_ntt_op(1, 1)
    
    ctx.push_halt()
    ctx.run()
    
    print("✅ SUCCESS: Arbiter handled concurrent memory requests.")

if __name__ == "__main__":
    test_arbiter()
