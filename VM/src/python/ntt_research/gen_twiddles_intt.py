import sys
import os

# FIX: Add current directory to path to find ntt_config_4k.py
sys.path.append(os.getcwd())

try:
    import ntt_config_4k as cfg
except ImportError:
    print("CRITICAL: ntt_config_4k.py not found in CWD")
    sys.exit(1)

N = cfg.N
Q = cfg.Q
PSI = cfg.PSI

PSI_INV = pow(PSI, -1, Q)
N_INV = pow(N, -1, Q)
print(f"Calculated N_INV: {N_INV}")

filename = "twiddles_combined.hex"
print(f"Generating {filename}...")

with open(filename, "w") as f:
    # Forward (Lower Half)
    for i in range(N):
        val = pow(PSI, i, Q)
        f.write(f"@{i:04x} {val:016x}\n")
    
    # Inverse (Upper Half)
    for i in range(N):
        val = pow(PSI_INV, i, Q)
        addr = i + N
        f.write(f"@{addr:04x} {val:016x}\n")

print("Done.")

# Append N_INV to config (Check if exists first to avoid dupes)
with open("ntt_config_4k.py", "r") as f:
    content = f.read()

if "N_INV" not in content:
    with open("ntt_config_4k.py", "a") as f:
        f.write(f"N_INV = {N_INV}\n")
else:
    print("N_INV already in config, skipping append.")
