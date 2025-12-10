# 🦁 LOGOS FHE Accelerator (Emulation Suite)

> **Hardware-Accelerated Fully Homomorphic Encryption (FHE)**
> *Compatible with Microsoft SEAL | Bit-Exact Verification | Python SDK*

---

## 🚀 Overview

**LOGOS** is a prototype hardware accelerator for Homomorphic Encryption (BFV Scheme). This repository contains the **Emulation Suite**, which allows developers to:
1.  Run FHE operations on a **Bit-Exact Verilog Model** (RTL).
2.  Interface with hardware using high-level **Python SDK**.
3.  Verify results against **Microsoft SEAL** library.

Currently implemented: **Private Set Intersection (PSI)** demo based on Homomorphic Difference-Square method.

---

## ✨ Key Features

*   **Microsoft SEAL Integration:** Generates cryptographically valid BFV parameters and vectors using the industry-standard SEAL library.
*   **Cycle-Accurate Emulation:** Runs Verilog RTL via Verilator to simulate real hardware behavior (Latency, Pipeline bubbles, DMA).
*   **Pipelined DMA:** High-performance data mover capable of 1 word/cycle throughput.
*   **Hybrid Architecture:** 
    *   Control Flow & Data Movement → **Verilog RTL**
    *   Complex Math (NTT/ALU) → **C++ DPI (Accelerated Model)**
*   **Python SDK:** No need to write Verilog or C++. Control the accelerator via `logos_sdk`.

---

## 🛠 Architecture

```mermaid
graph TD
    User[User / Python Script] -->|High Level API| SDK[Logos SDK]
    SDK -->|Commands| Driver[C++ Emulator Driver]
    Driver -->|DPI| RTL[Verilog Core (RTL)]
    Driver -.->|Math Verification| SEAL[Microsoft SEAL Lib]
    RTL -->|DMA Load/Store| RAM[Shadow Memory]



⚡ Quick Start (Run the Demo)
You don’t need to install Verilator or C++ compilers manually. We provide a Dockerized environment.
Prerequisites
Docker
Git
1. Clone & Setup
git clone https://github.com/magnumops/fhe-core.git logos-fhe
cd logos-fhe/VM


2. Build & Run PSI Demo
This single command will build the container, compile the RTL/C++ stack, generate SEAL keys/data, and run the Private Set Intersection demo.
docker build -t logos-dev:v6 .

docker run --rm -v $(pwd):/app -w /app logos-dev:v6 /bin/bash -c " \
    rm -rf build && mkdir build && cd build && \
    cmake .. && make seal_exporter logos_emu && \
    ./seal_exporter && cp *.bin .. && cd .. && \
    export PYTHONPATH=build && \
    python3 tests/demo_psi.py"


Expected Output
=== LOGOS FHE: PRIVATE SET INTERSECTION DEMO ===
Algorithm: Difference Square. Match if (A - B)^2 == 0
[SDK] Loading 4096 words to Slot 0...
[SDK] Loading 4096 words to Slot 1...
[SDK] Executing SUB (Slot0 - Slot1)...
[SDK] Executing SQUARE (Slot0 ^ 2)...

--- PSI RESULTS ---
Idx 0: Alice=0, Bob=0 -> DiffSq=0  MATCH!
Idx 1: Alice=1, Bob=2 -> DiffSq=1  .
...
Total Matches Found: 3585
Demo Completed Successfully.



🐍 SDK Usage Example
Want to build your own FHE application? Use logos_sdk.
import sys
sys.path.append('build') # Path to compiled logos_emu.so
from logos_sdk import LogosAccelerator

# 1. Initialize Accelerator (Load Modulus)
accel = LogosAccelerator(modulus=1152921504606830593)

# 2. Load Vectors (Alice and Bob)
alice_data = [1, 2, 3, 4]
bob_data   = [1, 5, 3, 9]

accel.load_vector(alice_data, slot=0)
accel.load_vector(bob_data,   slot=1)

# 3. Perform Homomorphic Operations
# (A - B)
accel.subtract() 

# (A - B)^2
accel.square()

# 4. Get Results (If result is 0, then A == B)
results = accel.read_result(length=4)
print(results) 
# Output: [0, 9, 0, 25] -> Indices 0 and 2 are matches!



📂 Repository Structure
src/rtl/ - Verilog Source Code (The Hardware).
ntt_engine.v - Main math core & state machine.
mem_arbiter.v - Memory controller.
src/emulator_core.cpp - C++ Driver. Bridges Python, Verilog, and SEAL.
tests/logos_sdk.py - Python SDK. High-level abstraction layer.
tests/demo_psi.py - Demo Application.
Dockerfile - Reproducible build environment.

⚠️ Current Status (Phase 7)
Status: Prototype / Research.
Math Backend: Currently uses C++ Shadow Memory for complex math operations (NTT/Mult) via DPI to guarantee correctness while the full Verilog ALU is being synthesized.
Performance: RTL Pipeline is active (1 word/clock DMA).

© 2025 LOGOS FHE Team.
