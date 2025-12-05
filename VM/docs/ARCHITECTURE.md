# Архитектура Logos FHE Accelerator (v3.0)

## C2: Container Diagram (System Context)

```mermaid
graph TD
    User[User / Python Test] -->|High Level API| SDK[Python SDK\n(LogosContext)]
    SDK -->|RNS Math| Math[RNS Math Core\n(CRT/Primes)]
    SDK -->|Native Calls| CPP[C++ Driver\n(emulator_core)]
    
    subgraph "Hardware Emulation Boundary"
        CPP -->|DPI-C| SIM[Verilator Simulation]
        
        subgraph "Logos Core (Verilog)"
            CP[Command Processor]
            NTT[NTT Engine]
            ALU[Vector ALU]
            
            MEM[(Multi-Bank RAM\n4 x 4096 words)]
            TWID[(Twiddle RAM\nDynamic Factors)]
        end
        
        CP -->|Control| NTT
        CP -->|Control| ALU
        NTT <-->|Read/Write| MEM
        ALU <-->|Read/Write| MEM
        NTT <-->|Read| TWID
    end
```

## C3: Data Flow (Diamond Loop Scenario)

```mermaid
sequenceDiagram
    participant Py as Python SDK
    participant Drv as C++ Driver
    participant CP as Command Processor
    participant Eng as NTT Engine/ALU
    participant Mem as FPGA Memory

    Note over Py, Mem: Step 1: Upload & Decompose
    Py->>Py: BigInt -> RNS Residues
    Py->>Drv: write_ram(residues) -> DPI
    Drv->>Mem: DMA Burst Write
    
    Note over Py, Mem: Step 2: Computation
    Py->>Drv: push_ntt_op(slot=0)
    Drv->>CP: Enqueue CMD
    CP->>Eng: Signal Start
    loop Processing
        Eng->>Mem: Read
        Eng->>Eng: Butterfly
        Eng->>Mem: Write
    end
    Eng->>CP: Done
    
    Note over Py, Mem: Step 3: ALU Operation
    Py->>Drv: push_alu_op(ADD, tgt=0, src=1)
    CP->>Eng: Signal ALU Mode
    loop Element-wise
        Eng->>Mem: Read A & B
        Eng->>Eng: Add Mod Q
        Eng->>Mem: Write A
    end
```
