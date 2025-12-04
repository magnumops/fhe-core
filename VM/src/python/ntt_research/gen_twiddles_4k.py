import math

def is_prime(n):
    if n % 2 == 0: return False
    for i in range(3, int(n**0.5)+1, 2):
        if n % i == 0: return False
    return True

def find_prime(N_points, min_val):
    # We need Q = 1 mod 2N
    step = 2 * N_points
    start = (min_val // step) * step + 1
    if start < min_val: start += step
    
    q = start
    while True:
        if is_prime(q):
            return q
        q += step

N = 4096
# Ищем простое число в районе 30 бит, чтобы точно влезло в 64 и было быстрым
# Min = 1 << 30
Q = find_prime(N, 1 << 30)
print(f"Selected Prime Q: {Q}")

# Находим примитивный корень g, затем psi
# psi^(2N) = 1 mod Q => psi has order 2N.
# g^(Q-1) = 1.
# psi = g^((Q-1)/(2N))

def find_primitive_root(q):
    # Simple check for generator
    # Factorize Q-1?
    # For generated prime Q = k*2N + 1, factors depend on k.
    # Let's brute force valid psi directly.
    # Order required is 2N = 8192.
    # Check if x^(2N) == 1 and x^N == -1 (or just != 1)
    
    required_order = 2 * N
    power = (q - 1) // required_order
    
    for g in range(2, 1000):
        psi = pow(g, power, q)
        if pow(psi, N, q) == q - 1: # psi^N = -1
            return psi
    return None

PSI = find_primitive_root(Q)
print(f"Selected PSI: {PSI}")

filename = "twiddles_4k.hex"
print(f"Generating {filename} for N={N}...")

with open(filename, "w") as f:
    # We need N coefficients (or N/2? DIT needs N/2 distinct values, but addressing logic handles it)
    # Our ROM is addressed by addr_w.
    # In Day 5 logic: w_idx = j * w_stride.
    # Max index is roughly N/2.
    # But let's fill N entries to be safe for now, size is small enough (4096 lines).
    for i in range(N):
        val = pow(PSI, i, Q)
        f.write(f"@{i:03x} {val:016x}\n") # i:03x assumes N=4096 fits in hex (FFF is 4095)

print("Done.")

# Save config for python test
with open("ntt_config_4k.py", "w") as f:
    f.write(f"N = {N}\n")
    f.write(f"Q = {Q}\n")
    f.write(f"PSI = {PSI}\n")
