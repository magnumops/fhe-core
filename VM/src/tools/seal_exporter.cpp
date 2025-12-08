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
    cout << "[Exporter] Wrote " << data.size() << " words to " << filename << endl;
}

int main() {
    cout << "=== SEAL DATA GENERATOR (Day 7) ===" << endl;

    EncryptionParameters parms(scheme_type::bfv);
    size_t poly_modulus_degree = 4096;
    parms.set_poly_modulus_degree(poly_modulus_degree);
    parms.set_coeff_modulus(CoeffModulus::Create(poly_modulus_degree, { 60 }));
    // CRITICAL FIX: Use Batching-compatible prime modulus
    parms.set_plain_modulus(PlainModulus::Batching(poly_modulus_degree, 20));

    SEALContext context(parms);
    KeyGenerator keygen(context);
    SecretKey secret_key = keygen.secret_key();
    PublicKey public_key;
    keygen.create_public_key(public_key);
    Encryptor encryptor(context, public_key);
    Evaluator evaluator(context);
    BatchEncoder batch_encoder(context);

    // 1. Generate Data (0, 1, 2, ... 4095)
    size_t slot_count = batch_encoder.slot_count();
    vector<uint64_t> pod_matrix_a(slot_count);
    for(size_t i=0; i<slot_count; i++) pod_matrix_a[i] = i; 

    Plaintext plain_a;
    batch_encoder.encode(pod_matrix_a, plain_a);

    // 2. Encrypt
    Ciphertext encrypted_a;
    encryptor.encrypt(plain_a, encrypted_a);

    // 3. Export raw coefficients (First polynomial only for Day 7 test)
    vector<uint64_t> host_a(poly_modulus_degree);
    const uint64_t* ptr_a = encrypted_a.data(0);
    for(size_t i=0; i<poly_modulus_degree; i++) host_a[i] = ptr_a[i];

    write_bin("vector_a.bin", host_a);
    
    // Export Modulus for verification
    auto modulus = parms.coeff_modulus()[0];
    vector<uint64_t> config = { modulus.value(), 0 };
    write_bin("config_math.bin", config);

    return 0;
}
