from functools import reduce

def extended_gcd(a, b):
    if a == 0: return b, 0, 1
    d, x1, y1 = extended_gcd(b % a, a)
    x = y1 - (b // a) * x1
    y = x1
    return d, x, y

def mod_inverse(a, m):
    d, x, y = extended_gcd(a, m)
    if d != 1: raise ValueError("Modular inverse does not exist")
    return (x % m + m) % m

def mod_pow(base, exp, mod):
    return pow(base, exp, mod)

class RNSBase:
    def __init__(self, moduli):
        self.moduli = moduli
        self.k = len(moduli)
        self.Q = reduce(lambda x, y: x * y, moduli)
        self.Mi = [self.Q // q for q in moduli]
        self.Yi = [mod_inverse(self.Mi[i], moduli[i]) for i in range(self.k)]

    def decompose(self, value):
        return [value % q for q in self.moduli]

    def compose(self, residues):
        acc = 0
        for i in range(self.k):
            acc += residues[i] * self.Mi[i] * self.Yi[i]
        return acc % self.Q

def generate_primes(n_log, count):
    N = 1 << n_log
    primes = []
    candidate = (1 << 30) + 1
    while len(primes) < count:
        if is_prime(candidate) and (candidate % (2*N) == 1):
            primes.append(candidate)
        candidate += (2*N)
    return primes

def is_prime(num):
    if num < 2: return False
    for i in range(2, int(num**0.5) + 1):
        if num % i == 0: return False
    return True

def reverse_bits(val, width):
    result = 0
    for _ in range(width):
        result = (result << 1) | (val & 1)
        val >>= 1
    return result

def generate_twiddles(n_log, q):
    N = 1 << n_log
    g = 2
    while True:
        if mod_pow(g, (q-1)//2, q) != 1 and mod_pow(g, q-1, q) == 1:
            psi = mod_pow(g, (q-1)//(2*N), q)
            psi_inv = mod_inverse(psi, q)
            if mod_pow(psi, N, q) == q-1:
                break
        g += 1
        
    w_forward = []
    for i in range(N):
        idx = reverse_bits(i, n_log) # Hardware DIT needs bit-reversed twiddles?
        # Actually Phase 2 twiddle_rom used linear index for 'w'.
        # Let's check ntt_control.v logic for addr_w.
        # It generates addresses based on stage.
        # For now let's assume standard order powers: psi^0, psi^1... 
        # and let AGU pick them.
        # Wait, Phase 2 `gen_twiddles.py` generated `pow(psi, i, q)`.
        # So we generate linear powers.
        w_forward.append(mod_pow(psi, i, q))
        
    w_inverse = []
    for i in range(N):
        w_inverse.append(mod_pow(psi_inv, i, q))
        
    return w_forward + w_inverse
