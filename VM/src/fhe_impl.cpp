#include <pybind11/pybind11.h> // <--- ДОБАВЛЕНО
#include "seal/seal.h"
#include <iostream>
#include <vector>
#include <memory>
#include <sstream> // Добавлено для std::stringstream

using namespace seal;

class FHEManager {
public:
    std::unique_ptr<SEALContext> context;
    std::unique_ptr<KeyGenerator> keygen;
    std::unique_ptr<Encryptor> encryptor;
    std::unique_ptr<Evaluator> evaluator;
    std::unique_ptr<Decryptor> decryptor;
    
    SecretKey secret_key;
    PublicKey public_key;

    FHEManager() {
        // 1. Настройка параметров шифрования (BFV схема)
        EncryptionParameters parms(scheme_type::bfv);
        size_t poly_modulus_degree = 4096;
        parms.set_poly_modulus_degree(poly_modulus_degree);
        
        // Коэффициенты
        parms.set_coeff_modulus(CoeffModulus::BFVDefault(poly_modulus_degree));
        
        // Модуль открытого текста
        parms.set_plain_modulus(1024);

        // 2. Создание контекста
        context = std::make_unique<SEALContext>(parms);

        // 3. Генерация ключей
        keygen = std::make_unique<KeyGenerator>(*context);
        secret_key = keygen->secret_key();
        keygen->create_public_key(public_key);

        // 4. Инструменты
        encryptor = std::make_unique<Encryptor>(*context, public_key);
        evaluator = std::make_unique<Evaluator>(*context);
        decryptor = std::make_unique<Decryptor>(*context, secret_key);
    }

    std::string encrypt_num(int value) {
        // Warning: BFV integer encoding is complex. For simple test we use string encoding provided by SEAL examples logic
        // But plain.to_string() usually works with hex representation of polynomial coeffs.
        // For BFV with small plain_modulus, integer N maps to constant polynomial N.
        
        // Преобразуем int в hex строку (SEAL Plaintext принимает hex строку коэффициентов)
        std::stringstream ss_hex;
        ss_hex << std::hex << value;
        Plaintext plain(ss_hex.str());

        Ciphertext encrypted;
        encryptor->encrypt(plain, encrypted);
        
        std::stringstream ss;
        encrypted.save(ss);
        return ss.str();
    }

    int decrypt_num(const std::string& serialized_cipher) {
        std::stringstream ss(serialized_cipher);
        Ciphertext encrypted;
        encrypted.load(*context, ss);

        Plaintext plain;
        decryptor->decrypt(encrypted, plain);
        
        // Декодируем hex строку обратно в int
        return std::stoi(plain.to_string(), nullptr, 16);
    }

    std::string add_ciphers(const std::string& c1_str, const std::string& c2_str) {
        std::stringstream ss1(c1_str);
        std::stringstream ss2(c2_str);
        
        Ciphertext c1, c2, result;
        c1.load(*context, ss1);
        c2.load(*context, ss2);

        evaluator->add(c1, c2, result);

        std::stringstream ss_out;
        result.save(ss_out);
        return ss_out.str();
    }
};

FHEManager* g_fhe = nullptr;

void init_fhe() { if (!g_fhe) g_fhe = new FHEManager(); }

void py_init_fhe() { init_fhe(); }

pybind11::bytes py_encrypt(int value) {
    if (!g_fhe) init_fhe();
    return g_fhe->encrypt_num(value);
}

int py_decrypt(pybind11::bytes cipher) {
    if (!g_fhe) return -1;
    return g_fhe->decrypt_num(cipher);
}

pybind11::bytes py_add(pybind11::bytes c1, pybind11::bytes c2) {
    if (!g_fhe) return std::string();
    return g_fhe->add_ciphers(c1, c2);
}
