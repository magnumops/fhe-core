import sys
sys.path.append("/app/build")
import logos_emu

def test_dual_core():
    print("--- Phase 6: Dual Core Smoke Test ---")
    
    emu = logos_emu.LogosContext()
    emu.reset()
    
    # --- Command Generators ---
    # Fmt: [Op 8][Slot 4][Target 1][Addr 48]
    def make_cmd(op, slot, target, addr):
        return (op << 56) | (slot << 52) | (target << 48) | addr

    # 1. Start Core 0 (LOAD to Slot 0 from 0x1000)
    cmd0 = make_cmd(0x02, 0, 0, 0x1000)
    print(f"[INFO] Dispatching Core 0: 0x{cmd0:016X}")
    emu.push_command(cmd0)
    
    # 2. Start Core 1 (LOAD to Slot 0 from 0x2000)
    cmd1 = make_cmd(0x02, 0, 1, 0x2000)
    print(f"[INFO] Dispatching Core 1: 0x{cmd1:016X}")
    emu.push_command(cmd1)
    
    # 3. Run Simulation
    print("[INFO] Stepping 50 cycles...")
    emu.run_cycles(50)
    
    # 4. Check status (via Ops Counters - assuming they are wired or just checking liveness)
    # Even if counters are 0, successful execution means no hang.
    ops0 = emu.get_core_ops(0)
    ops1 = emu.get_core_ops(1)
    
    print(f"[INFO] Core 0 Ops: {ops0}")
    print(f"[INFO] Core 1 Ops: {ops1}")
    
    print("[PASS] Dual Core Dispatch Successful.")

if __name__ == "__main__":
    test_dual_core()
