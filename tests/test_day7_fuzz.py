import sys
import random
import logos_emu
sys.path.append("/app/src/python")
from logos_sdk import RNSContext

def fuzz_test():
    print("=== LOGOS FUZZER v1.0 ===")
    N = 4096
    ctx = RNSContext(N, 12, num_moduli=1)
    
    # Operations pool
    OP_CODES = [
        (0x02, "LOAD"),
        (0x03, "STORE"),
        (0x04, "LOAD_W"),
        (0x10, "NTT"),
        (0x11, "INTT"),
        (0x20, "ADD"),
        (0x21, "SUB"),
        (0x22, "MULT"),
        (0x0F, "READ_PERF")
    ]
    
    print("State: Generating random instruction stream...")
    iterations = 50
    
    # Fuzzing Loop
    for i in range(iterations):
        # 1. Reset
        ctx.emu.reset_state()
        
        # 2. Generate random batch of commands (1 to 10 commands)
        batch_size = random.randint(1, 10)
        cmds = []
        for _ in range(batch_size):
            op, name = random.choice(OP_CODES)
            slot = random.randint(0, 3)
            addr = random.randint(0, 1024) * 8 # Random aligned address
            
            if op == 0x20 or op == 0x21 or op == 0x22: # ALU ops need 2 slots
                src = random.randint(0, 3)
                ctx.emu.push_alu_op(op, slot, src)
                cmds.append(f"{name}({slot}, {src})")
            elif op == 0x10 or op == 0x11: # NTT
                ctx.emu.push_ntt_op(slot, op == 0x11)
                cmds.append(f"{name}({slot})")
            elif op == 0x0F: # Perf
                ctx.emu.push_read_perf_op(0x30000000)
                cmds.append(f"{name}")
            else: # Memory
                if op == 0x02: ctx.emu.push_load_op(slot, addr)
                elif op == 0x03: ctx.emu.push_store_op(slot, addr)
                else: ctx.emu.push_load_w_op(addr)
                cmds.append(f"{name}")
        
        # 3. Add Halt
        ctx.emu.push_halt()
        
        # 4. Run and Catch Hangs
        print(f"[{i+1}/{iterations}] Running batch: {', '.join(cmds)}", end=" ... ")
        try:
            ctx.emu.run()
            print("OK")
        except Exception as e:
            print(f"\n[FAIL] Crashed on batch: {cmds}")
            print(f"Error: {e}")
            exit(1)

    print("\n[PASS] Fuzzer survived 50 random batches.")

if __name__ == "__main__":
    fuzz_test()
