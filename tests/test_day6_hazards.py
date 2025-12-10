import sys
import logos_emu
sys.path.append("/app/build")

def test_dual_core():
    print("--- Starting Day 6: Dual Core Hazard Test ---")
    ctx = logos_emu.LogosContext()
    
    print("[1] Sending Parallel Commands...")
    ctx.push_ntt_op(0, 0)
    ctx.push_ntt_op(1, 1)
    
    print("[2] Sending HALT command...")
    ctx.push_halt() 
    
    print("[3] Running simulation...")
    ctx.run()
    
    print("✅ SUCCESS: Dual Core Execution finished without deadlocks.")

if __name__ == "__main__":
    test_dual_core()
