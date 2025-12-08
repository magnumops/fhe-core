#include "seal/seal.h"
#include <fstream>
#include <iostream>
#include <vector>

using namespace std;
using namespace seal;

void write_bin(const string& filename, const vector<uint64_t>& data) {
    ofstream out(filename, ios::binary);
    if (!out) { cerr << "Cannot open " << filename << endl; exit(1); }
    out.write(reinterpret_cast<const char*>(data.data()), data.size() * sizeof(uint64_t));
    out.close();
}

int main() {
    cout << "=== SEAL PSI DATA GENERATOR (Day 8) ===" << endl;

    EncryptionParameters parms(scheme_type::bfv);
    parms.set_poly_modulus_degree(4096);
    parms.set_coeff_modulus(CoeffModulus::Create(4096, { 60 }));
    parms.set_plain_modulus(PlainModulus::Batching(4096, 20));

    SEALContext context(parms);
    BatchEncoder batch_encoder(context);
    size_t slot_count = batch_encoder.slot_count();

    // 1. Generate Vectors
    // Alice: 0, 1, 2, 3, 4, 5...
    vector<uint64_t> vec_a(slot_count);
    for(size_t i=0; i<slot_count; i++) vec_a[i] = i;

    // Bob: 0, 2, 4, 6, 8... (Only even match)
    vector<uint64_t> vec_b(slot_count);
    for(size_t i=0; i<slot_count; i++) vec_b[i] = i * 2;

    // 2. Export Raw Plaintexts (Simulating "Decrypted" input for this specific demo level)
    // In a real encrypted PSI, we would encrypt these. 
    // For Day 8 Demo simplicity, we operate on Plaintexts inside the emulator 
    // to clearly see the "Zero" result without noise handling logic.
    // The emulator treats them as "Data to be processed".
    
    // We export the raw integers directly to simulate the "Payload".
    write_bin("psi_vec_a.bin", vec_a);
    write_bin("psi_vec_b.bin", vec_b);
    
    auto modulus = parms.coeff_modulus()[0];
    vector<uint64_t> config = { modulus.value(), 0 };
    write_bin("config_math.bin", config);
    
    cout << "Generated psi_vec_a.bin and psi_vec_b.bin" << endl;
    return 0;
}
