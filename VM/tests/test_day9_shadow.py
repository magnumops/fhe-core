import sys
from logos import LogosContext

def test_god_mode():
    print("--- Starting Shadow Execution Test ---")
    
    # 1. Инициализация
    ctx = LogosContext()
    
    # 2. Создаем переменные
    # Пользователь думает, что работает с шифрованием,
    # а мы под капотом ведем теневой учет.
    a = ctx.encrypt(10)
    b = ctx.encrypt(20)
    c = ctx.encrypt(5)
    
    print(f"[Input] a=10, b=20, c=5")

    # 3. Цепочка вычислений: res = (a + b) + c
    print("[Compute] res = (a + b) + c")
    temp = a + b
    res = temp + c
    
    # 4. Проверка "Бога"
    # Это ключевой момент. Мы проверяем корректность БЕЗ знания секретного ключа (в теории),
    # но эмулятор имеет доступ ко всему.
    if not res.debug_check():
        sys.exit(1)
        
    # Проверка значений вручную для теста
    if res.decrypt() == 35:
        print("🎉 Day 9 Complete: Shadow Execution verified!")
    else:
        sys.exit(1)

if __name__ == "__main__":
    test_god_mode()
