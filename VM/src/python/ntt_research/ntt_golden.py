import math

class NTTEngine:
    def __init__(self, N, q, psi):
        self.N = N
        self.q = q
        self.psi = psi # 2N-th root of unity (psi^N = -1 mod q)
        
        # Precompute Powers of Psi
        # For hardware friendliness (Cooley-Tukey), we often need them in bit-reversed order
        # But for Day 1 Reference, let's keep it standard to verify math.
        self.psi_powers = [pow(psi, i, q) for i in range(2 * N)]
        self.inv_psi_powers = [pow(psi, -i, q) for i in range(2 * N)] # Python handles modular inverse with pow(a, -1, q) in newer versions, but let's be safe
        
        # Correct modular inverse for negative powers manually if needed, 
        # but pow(base, -exp, mod) works in Python 3.8+
        
        self.n_inv = pow(N, -1, q)

    def bit_reverse(self, x, bits):
        y = 0
        for i in range(bits):
            if (x >> i) & 1:
                y |= (1 << (bits - 1 - i))
        return y

    def ntt_forward_naive(self, poly):
        """O(N^2) implementation for validation"""
        # Negacyclic NTT formula: A_j = sum( a_i * psi^( (2i+1)*j ) ) 
        # Wait, SEAL uses a slightly different flavor:
        # Standard Negacyclic: a_i -> a_i * psi^i, then Standard FFT.
        # Let's implement the iterative Cooley-Tukey directly as it will be in HW.
        
        # Step 1: Bit Reverse Copy? Or output bit-reversed?
        # Let's use Iterative Cooley-Tukey (Time Decimation). 
        # Input: Standard Order. Output: Bit-Reversed Order.
        
        a = list(poly)
        m = 1
        k_max = int(math.log2(self.N))
        
        for k in range(k_max):
            # t = N / (2 * m)
            # We iterate butterflies
            # Gap between dual nodes is m.
            # Block size is 2m.
            
            gap = self.N // (2**(k+1)) # Correct stride for CT? 
            # Actually, let's stick to a very specific structure:
            # "Introduction to Algorithms" or SEAL's implementation.
            
            # Let's try the simpler "Multiply by psi^i then FFT" approach for the Golden Model first.
            pass
        
        # FALLBACK: The Naive Matrix approach is the ultimate truth for unit tests.
        # Negacyclic NTT maps poly a(x) to evaluations at odd powers of psi.
        # Roots: psi^1, psi^3, psi^5, ..., psi^(2N-1)
        res = []
        for i in range(self.N):
            # root = psi^(2*bit_reverse(i) + 1) ... depends on ordering.
            # Standard order roots: psi^1, psi^3, ...
            root_idx = 2 * i + 1
            root = pow(self.psi, root_idx, self.q)
            
            val = 0
            for j in range(self.N):
                term = (poly[j] * pow(root, j, self.q)) % self.q
                val = (val + term) % self.q
            res.append(val)
        return res

    def ntt_inverse_naive(self, poly):
        # Inverse: similar but with psi^-1 and * N^-1
        res = []
        for i in range(self.N):
            # To recover coefficient a_i
            # a_i = 1/N * sum( A_j * (root_j)^-i )
            
            val = 0
            for j in range(self.N):
                root_idx = 2 * j + 1
                root = pow(self.psi, root_idx, self.q)
                inv_root = pow(root, -1, self.q)
                
                term = (poly[j] * pow(inv_root, i, self.q)) % self.q
                val = (val + term) % self.q
            
            val = (val * self.n_inv) % self.q
            res.append(val)
        return res

# --- CONFIGURATION for N=8, q=17 ---
# 17 is prime. 17 = 1 mod 16.
# Generator is 3. 3^16 = 1 mod 17.
# psi (16-th root) such that psi^8 = -1.
# 3^8 = 16 = -1 mod 17.
# So psi = 3.

N = 8
Q = 17
PSI = 3

engine = NTTEngine(N, Q, PSI)

# Test Data
data_in = [0, 1, 2, 3, 4, 5, 6, 7]
print(f"Input: {data_in}")

# 1. Forward NTT
ntt_res = engine.ntt_forward_naive(data_in)
print(f"NTT:   {ntt_res}")

# 2. Inverse NTT
intt_res = engine.ntt_inverse_naive(ntt_res)
print(f"INTT:  {intt_res}")

# 3. Validation
if intt_res == data_in:
    print("\nSUCCESS: Identity Verified (INTT(NTT(x)) == x)")
    
    # Export Twiddles for Hardware (Just to visualize)
    # We need odd powers of psi: 1, 3, 5, 7, 9, 11, 13, 15
    print("\n[Twiddle Factors for Verilog ROM]")
    for i in range(N):
        p = pow(PSI, 2*i + 1, Q)
        print(f"ADDR {i:02x}: {p:04x}")
else:
    print("\nFAILURE: Mismatch!")
    exit(1)
