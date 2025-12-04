import sys
import logos_emu # Низкоуровневый C++ модуль

class CipherVar:
    """
    Умная переменная, хранящая и шифртекст, и его 'теневое' значение.
    """
    def __init__(self, context, plaintext_val=None, ciphertext_bytes=None):
        self.ctx = context
        self.pt = plaintext_val # Shadow value (int)
        self.ct = ciphertext_bytes # Real FHE value (bytes)
    
    def __add__(self, other):
        if not isinstance(other, CipherVar):
            raise TypeError("Can only add CipherVar to CipherVar")
        
        # 1. Real FHE Operation (C++ / SEAL)
        new_ct = logos_emu.fhe_add(self.ct, other.ct)
        
        # 2. Shadow Operation (Python)
        new_pt = self.pt + other.pt
        
        return CipherVar(self.ctx, new_pt, new_ct)

    def decrypt(self):
        """Возвращает расшифрованное значение."""
        return logos_emu.fhe_decrypt(self.ct)

    def debug_check(self):
        """
        GOD MODE: Расшифровывает и сравнивает с теневым значением.
        """
        real_val = self.decrypt()
        if real_val == self.pt:
            print(f"✅ DEBUG CHECK: OK. Real({real_val}) == Shadow({self.pt})")
            return True
        else:
            print(f"❌ DEBUG CHECK: FAIL! Real({real_val}) != Shadow({self.pt})")
            return False

class LogosContext:
    def __init__(self):
        print("[Logos] Initializing FHE Engine...")
        logos_emu.fhe_init()
    
    def encrypt(self, value):
        ct_bytes = logos_emu.fhe_encrypt(value)
        return CipherVar(self, value, ct_bytes)

