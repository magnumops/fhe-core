# Logos FHE Emulator v4.0 (Observability Release)

## New Features
*   **VCD on Demand:** Programmatic control of waveform dumping (`ctx.start_trace()`).
*   **Smart Triggers:** `TraceGuard` context manager auto-saves traces only on crash.
*   **Hardware Counters:** Cycle-accurate metrics for NTT, ALU, and Active Cycles.
*   **Profiling Suite:** `LogosProfiler` class and Micro-benchmarks.
*   **Roofline Analysis:** Automated efficiency report (currently >99% efficiency).

## Reliability
*   **Fuzzer:** Validated against random instruction streams.
*   **CI/CD:** Github Actions pipeline configured.

## Usage
\`\`\`python
from logos_sdk import RNSContext, LogosProfiler, TraceGuard

ctx = RNSContext(4096, 12)
profiler = LogosProfiler(ctx)

with TraceGuard(ctx.emu, "my_experiment"):
    start = profiler.capture()
    # ... run operations ...
    end = profiler.capture()
    print(f"Cycles: {end['total_cycles'] - start['total_cycles']}")
\`\`\`
