import sys
import os
import logos_emu

def test_trace():
    print("[TEST] Initializing Emulator...")
    emu = logos_emu.Emulator()
    trace_file = "canary_trace.vcd"
    if os.path.exists(trace_file): os.remove(trace_file)
        
    print(f"[TEST] Starting Trace -> {trace_file}")
    emu.start_trace(trace_file)
    print("[TEST] Running reset sequence...")
    emu.reset_state()
    print("[TEST] Stopping Trace...")
    emu.stop_trace()
    
    if os.path.exists(trace_file) and os.path.getsize(trace_file) > 100:
        print(f"[SUCCESS] Trace created ({os.path.getsize(trace_file)} bytes).")
    else:
        print("[FAIL] Trace file empty or missing.")
        exit(1)

if __name__ == "__main__":
    test_trace()
