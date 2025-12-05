#include <pybind11/pybind11.h>
#include <pybind11/stl.h>
#include <pybind11/numpy.h>
#include "seal/seal.h"
#include <vector>
#include <memory>
#include <iostream>

namespace py = pybind11;
using namespace seal;

class SealContextWrapper {
public:
    std::shared_ptr<SEALContext> context;
    std::unique_ptr<KeyGenerator> keygen;
    SecretKey secret_key;
    PublicKey public_key;
    RelinKeys relin_keys;
    std::unique_ptr<Encryptor> encryptor;
    std::unique_ptr<Evaluator> evaluator;
    std::unique_ptr<Decryptor> decryptor;
    std::unique_ptr<BatchEncoder> encoder;
    
    size_t poly_modulus_degree;

    SealContextWrapper(size_t poly_degree, const std::vector<uint64_t>& moduli) 
        : poly_modulus_degree(poly_degree) 
    {
        EncryptionParameters parms(scheme_type::bfv);
        parms.set_poly_modulus_degree(poly_degree);
        std::vector<Modulus> mods;
        for (uint64_t m : moduli) mods.push_back(Modulus(m));
        parms.set_coeff_modulus(mods);
        parms.set_plain_modulus(65537);

        context = std::make_shared<SEALContext>(parms);
        
        // Validation Logic
        if (!context->parameters_set()) {
            std::cerr << "[CPP] SEAL Context Invalid! Reason: " 
                      << context->parameter_error_message() << std::endl;
        } else {
            auto context_data = context->key_context_data();
            std::cout << "[CPP] SEAL Context Valid. Chain size: " << context->key_context_data()->chain_index() + 1 << std::endl;
            std::cout << "[CPP] Coeff Modulus Size (Top): " << context_data->parms().coeff_modulus().size() << std::endl;
        }

        keygen = std::make_unique<KeyGenerator>(*context);
        secret_key = keygen->secret_key();
        keygen->create_public_key(public_key);
        keygen->create_relin_keys(relin_keys);
        encryptor = std::make_unique<Encryptor>(*context, public_key);
        evaluator = std::make_unique<Evaluator>(*context);
        decryptor = std::make_unique<Decryptor>(*context, secret_key);
        encoder = std::make_unique<BatchEncoder>(*context);
    }

    Ciphertext encrypt(const std::vector<int64_t>& data) {
        Plaintext plain;
        encoder->encode(data, plain);
        Ciphertext encrypted;
        encryptor->encrypt(plain, encrypted);
        return encrypted;
    }

    std::vector<int64_t> decrypt(const Ciphertext& encrypted) {
        Plaintext plain;
        decryptor->decrypt(encrypted, plain);
        std::vector<int64_t> result;
        encoder->decode(plain, result);
        return result;
    }

    std::vector<uint64_t> get_poly_component(Ciphertext& ct, size_t poly_idx, size_t rns_idx) {
        size_t N = ct.poly_modulus_degree();
        size_t K = ct.coeff_modulus_size();
        size_t Size = ct.size();
        
        if (poly_idx >= Size) {
            std::cerr << "[CPP] Poly Error: " << poly_idx << " >= " << Size << std::endl;
            throw std::runtime_error("Poly index out of bounds");
        }
        if (rns_idx >= K) {
            std::cerr << "[CPP] RNS Error: " << rns_idx << " >= " << K << std::endl;
            throw std::runtime_error("RNS index out of bounds");
        }
        
        uint64_t* ptr = ct.data();
        size_t offset = poly_idx * (N * K) + rns_idx * N;
        
        return std::vector<uint64_t>(ptr + offset, ptr + offset + N);
    }

    void set_poly_component(Ciphertext& ct, size_t poly_idx, size_t rns_idx, const std::vector<uint64_t>& data) {
        size_t N = ct.poly_modulus_degree();
        size_t K = ct.coeff_modulus_size();
        size_t Size = ct.size();
        
        if (data.size() != N) throw std::runtime_error("Data size mismatch");
        if (poly_idx >= Size) {
            std::cerr << "[CPP] Poly Error: " << poly_idx << " >= " << Size << std::endl;
            throw std::runtime_error("Poly index out of bounds");
        }
        if (rns_idx >= K) {
            std::cerr << "[CPP] RNS Error: " << rns_idx << " >= " << K << std::endl;
            throw std::runtime_error("RNS index out of bounds");
        }
        
        uint64_t* ptr = ct.data(); 
        size_t offset = poly_idx * (N * K) + rns_idx * N;
        
        std::copy(data.begin(), data.end(), ptr + offset);
    }
    
    void resize_ct(Ciphertext& ct, size_t size) {
        ct.resize(*context, size);
    }
};

void init_fhe(py::module &m) {
    py::class_<Ciphertext>(m, "Ciphertext")
        .def(py::init<>());

    py::class_<SealContextWrapper>(m, "SealContext")
        .def(py::init<size_t, const std::vector<uint64_t>&>())
        .def("encrypt", &SealContextWrapper::encrypt)
        .def("decrypt", &SealContextWrapper::decrypt)
        .def("get_poly", &SealContextWrapper::get_poly_component)
        .def("set_poly", &SealContextWrapper::set_poly_component)
        .def("resize_ct", &SealContextWrapper::resize_ct);
}
