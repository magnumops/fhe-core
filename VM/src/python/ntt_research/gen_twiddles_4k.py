import math

def is_prime(n):
    if n % 2 == 0: return False
    for i in range(3, int(n**0.5)+1, 2):
        if n % i == 0: return False
    return True

def find_prime(N_points, min_val):
    # Q = 1 mod 2N
    step = 2 * N_points
    start = (min_val // step) * step + 1
    if start < min_val: start += step
    
    q = start
    while True:
        if is_prime(q):
            return q
        q += step

N = 4096
# 30 бит достаточно для теста и влезает в uint64
Q = find_prime(N, 1 << 30)
print(f"Selected Prime Q: {Q}")

def find_primitive_root(q):
    required_order = 2 * N
    power = (q - 1) // required_order
    # Ищем g, такое что g^((Q-1)/2N) имеет порядок 2N
    # То есть (g^power)^N = -1 mod Q
    for g in range(2, 10000):
        psi = pow(g, power, q)
        if pow(psi, N, q) == q - 1: # psi^N == -1
            return psi
    return None

PSI = find_primitive_root(Q)
print(f"Selected PSI: {PSI}")

filename = "twiddles_4k.hex"
print(f"Generating {filename} for N={N}...")

with open(filename, "w") as f:
    for i in range(N):
        val = pow(PSI, i, Q)
        f.write(f"@{i:03x} {val:016x}\n")

print("Done.")

# Сохраняем конфиг для Python-тестов и grep-а
with open("ntt_config_4k.py", "w") as f:
    f.write(f"N = {N}\n")
    f.write(f"Q = {Q}\n")
    f.write(f"PSI = {PSI}\n")
