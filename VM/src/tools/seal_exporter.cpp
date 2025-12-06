#include <iostream>
#include <fstream>
#include <vector>
#include <cstdint>
#include <algorithm>
#include "seal/seal.h"

using namespace std;
using namespace seal;

typedef unsigned __int128 uint128_t;

// --- MATH UTILS ---

// Modular Exponentiation: (base^exp) % mod
uint64_t power_mod(uint64_t base, uint64_t exp, uint64_t mod) {
    uint64_t res = 1;
    uint128_t b = base;
    while (exp > 0) {
        if (exp % 2 == 1) res = (uint64_t)(( (uint128_t)res * b ) % mod);
        b = (b * b) % mod;
        exp /= 2;
    }
    return res;
}

// Modular Inverse using Fermat's Little Theorem (for prime mod)
uint64_t inverse_mod(uint64_t n, uint64_t mod) {
    return power_mod(n, mod - 2, mod);
}

// Bit Reversal (Permutation)
uint32_t bit_reverse(uint32_t n, int bits) {
    uint32_t r = 0;
    for (int i = 0; i < bits; i++) {
        if ((n >> i) & 1) {
            r |= (1 << (bits - 1 - i));
        }
    }
    return r;
}

// Check if root is a primitive 2N-th root of unity
bool is_primitive_root(uint64_t root, uint64_t n, uint64_t mod) {
    // Check root^(2N) == 1
    if (power_mod(root, 2 * n, mod) != 1) return false;
    // Check root^N == -1 (or just != 1) to ensure order is exactly 2N
    if (power_mod(root, n, mod) == 1) return false;
    return true;
}

// Find primitive 2N-th root
uint64_t find_psi(uint64_t n, uint64_t mod) {
    // We iterate through candidates. 
    // Since q = k*2N + 1, such root exists.
    // Try small integers as generators first.
    // Ideally we find a generator 'g' for the whole field, then psi = g^k.
    // Or just brute force verify.
    
    // Quick method:
    // 1. Find a generator g (randomly or seq).
    // 2. psi = g^((q-1)/(2N))
    
    uint64_t limit = (mod - 1) / (2 * n);
    
    for (uint64_t g = 2; g < 1000; g++) {
        uint64_t psi = power_mod(g, limit, mod);
        if (is_primitive_root(psi, n, mod)) {
            return psi;
        }
    }
    cerr << "Failed to find root!" << endl;
    exit(1);
}

// --- FILE IO ---

void write_vector(const string& filename, const vector<uint64_t>& vec) {
    ofstream out(filename, ios::binary);
    if (!out) { cerr << "Failed to open " << filename << endl; exit(1); }
    out.write(reinterpret_cast<const char*>(vec.data()), vec.size() * sizeof(uint64_t));
    out.close();
    cout << "[Exporter] Wrote " << vec.size() << " words to " << filename << endl;
}

// --- MAIN ---

int main() {
    cout << "=== SEAL GOLDEN VECTOR & TWIDDLE GENERATOR (Day 5) ===" << endl;

    size_t poly_degree = 4096;
    int log_n = 12; // 2^12 = 4096

    // 1. Setup SEAL to get Modulus
    EncryptionParameters parms(scheme_type::bfv);
    parms.set_poly_modulus_degree(poly_degree);
    parms.set_coeff_modulus(CoeffModulus::BFVDefault(poly_degree));
    parms.set_plain_modulus(PlainModulus::Batching(poly_degree, 20));
    SEALContext context(parms);

    if (!context.parameters_set()) {
        cerr << "SEAL Params Error: " << context.parameter_error_message() << endl; return 1;
    }

    auto &coeff_modulus = context.key_context_data()->parms().coeff_modulus();
    uint64_t q = coeff_modulus[0].value();
    cout << "Modulus q: " << q << endl;

    // 2. Calculate Hardware Parameters
    
    // A. Barrett Mu = floor(2^128 / q)
    uint128_t dividend = (uint128_t)1 << 64; 
    dividend = dividend * ((uint128_t)1 << 64); // 2^128
    // Note: Actually 2^128 cannot be represented in uint128_t (max is 2^128-1).
    // Trick: (2^128 - 1) / q is close enough, or handle overflow.
    // For q ~ 60 bits, the error of using (2^128-1) is negligible for reduction range < q^2.
    // Let's use (2^128 - 1) / q.
    uint128_t max_u128 = (~(uint128_t)0);
    uint64_t mu = (uint64_t)(max_u128 / q);
    // If exact 2^128/q is needed and remainder is non-zero, it might be +1. 
    // But standard Barrett usually works with floor((2^k)/q).
    cout << "Barrett Mu: " << mu << endl;

    // B. N Inverse
    uint64_t n_inv = inverse_mod(poly_degree, q);
    cout << "N Inverse: " << n_inv << endl;

    // Export Config
    vector<uint64_t> config = {q, mu, n_inv};
    write_vector("golden_config.bin", config);

    // 3. Generate Twiddles
    // We need Bit-Reversed powers of psi.
    // Standard Cooley-Tukey DIT:
    // For each stage... hardware usually expects pre-scrambled twiddles.
    // Pattern: W[i] = psi^(bit_reverse(i)) for i in 0..N-1.
    // Wait, DIT usually needs psi^br(i) but let's check Phase 2 python script convention.
    // Convention: twiddle[i] = psi^(bit_reverse_copy(i))
    
    uint64_t psi = find_psi(poly_degree, q);
    cout << "Primitive Root psi: " << psi << endl;

    vector<uint64_t> twiddles(poly_degree);
    // For NTT (Forward), we use powers of psi.
    for (size_t i = 0; i < poly_degree; i++) {
        // Bit Reverse index 'i' in 'log_n' bits
        // Actually, for size N=4096, standard MSR approach or Hexl:
        // Let's stick to simple Bit-Reversed Table for now.
        // It's the most standard "ROM friendly" layout.
        uint32_t idx_rev = bit_reverse(i, log_n);
        // But wait, usually index 0 is skipped or is 1.
        // Let's generate simple Powers Table first: P[i] = psi^i.
        // Then reorder.
        // Hardware Address 'i' gets P[bit_rev(i)].
        
        // Actually, standard HW DIT iterates i from 0 to N/2.
        // Let's make full N size table just in case.
        
        uint64_t w = power_mod(psi, idx_rev, q);
        twiddles[i] = w;
    }
    
    // Also Generate INTT Twiddles (Inverse Psi)
    // psi^-1
    uint64_t psi_inv = inverse_mod(psi, q);
    vector<uint64_t> itwiddles(poly_degree);
    for (size_t i = 0; i < poly_degree; i++) {
        uint32_t idx_rev = bit_reverse(i, log_n);
        uint64_t w = power_mod(psi_inv, idx_rev, q);
        itwiddles[i] = w;
    }

    // Combine into one file (NTT first, then INTT)
    // 2*N words
    vector<uint64_t> all_twiddles;
    all_twiddles.insert(all_twiddles.end(), twiddles.begin(), twiddles.end());
    all_twiddles.insert(all_twiddles.end(), itwiddles.begin(), itwiddles.end());
    
    write_vector("golden_twiddles.bin", all_twiddles);

    // 4. Generate Input Data
    BatchEncoder batch_encoder(context);
    vector<uint64_t> pod_matrix(poly_degree);
    for (size_t i = 0; i < poly_degree; i++) pod_matrix[i] = i; 

    Plaintext plaintext;
    batch_encoder.encode(pod_matrix, plaintext);
    
    vector<uint64_t> plain_vec(poly_degree);
    const uint64_t* data_ptr = plaintext.data();
    for(size_t i=0; i<plaintext.coeff_count(); i++) plain_vec[i] = data_ptr[i];
    for(size_t i=plaintext.coeff_count(); i<poly_degree; i++) plain_vec[i] = 0;
    
    write_vector("golden_input.bin", plain_vec);

    return 0;
}
