#include <iostream>
#include <fstream>
#include <vector>
#include <cstdint>
#include "seal/seal.h"

using namespace std;
using namespace seal;

void write_vector(const string& filename, const vector<uint64_t>& vec) {
    ofstream out(filename, ios::binary);
    if (!out) { cerr << "Failed to open " << filename << endl; exit(1); }
    out.write(reinterpret_cast<const char*>(vec.data()), vec.size() * sizeof(uint64_t));
    out.close();
    cout << "[Exporter] Wrote " << vec.size() << " words to " << filename << endl;
}

int main() {
    cout << "=== SEAL GOLDEN VECTOR GENERATOR (Day 4 Fix) ===" << endl;

    size_t poly_modulus_degree = 4096;
    EncryptionParameters parms(scheme_type::bfv);
    parms.set_poly_modulus_degree(poly_modulus_degree);
    parms.set_coeff_modulus(CoeffModulus::BFVDefault(poly_modulus_degree));
    
    // FIX: Mandatory Plain Modulus for BFV
    // Requesting ~20 bit prime compatible with batching for N=4096
    parms.set_plain_modulus(PlainModulus::Batching(poly_modulus_degree, 20));
    
    SEALContext context(parms);
    
    // SAFETY CHECK
    if (!context.parameters_set()) {
        cerr << "CRITICAL ERROR: SEAL Parameters are invalid!" << endl;
        cerr << context.parameter_error_message() << endl;
        return 1;
    }

    auto &context_data = *context.key_context_data();
    auto &coeff_modulus = context_data.parms().coeff_modulus();
    uint64_t modulus = coeff_modulus[0].value();
    
    cout << "[Exporter] Generated Modulus q: " << modulus << endl;
    cout << "[Exporter] Plain Modulus t: " << context_data.parms().plain_modulus().value() << endl;
    
    // 2. Export Config
    vector<uint64_t> config(3);
    config[0] = modulus;
    config[1] = 0; // Mu placeholder
    config[2] = 0; // N_inv placeholder
    write_vector("golden_config.bin", config);

    // 3. Generate Input Data
    BatchEncoder batch_encoder(context);
    vector<uint64_t> pod_matrix(poly_modulus_degree);
    for (size_t i = 0; i < poly_modulus_degree; i++) pod_matrix[i] = i; 

    Plaintext plaintext;
    batch_encoder.encode(pod_matrix, plaintext);
    
    // Extract raw data
    vector<uint64_t> plain_vec(poly_modulus_degree);
    const uint64_t* data_ptr = plaintext.data();
    // Copy active coeffs
    for(size_t i=0; i<plaintext.coeff_count(); i++) plain_vec[i] = data_ptr[i];
    // Pad rest with 0
    for(size_t i=plaintext.coeff_count(); i<poly_modulus_degree; i++) plain_vec[i] = 0;
    
    write_vector("golden_input.bin", plain_vec);

    return 0;
}
