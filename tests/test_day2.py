import sys
import os

# Добавляем папку build в путь, чтобы Python нашел скомпилированный .so файл
# В Dockerfile мы будем собирать в /app/build
sys.path.append("/app/build")

try:
    import spike_pybind
    print("✅ SUCCESS: Module 'spike_pybind' imported successfully.")
except ImportError as e:
    print(f"❌ FAIL: Could not import 'spike_pybind'. Error: {e}")
    sys.exit(1)

# Тест 1: Сложение
result = spike_pybind.add(2, 3)
expected = 5
if result == expected:
    print(f"✅ Test 1 Passed: 2 + 3 = {result}")
else:
    print(f"❌ Test 1 Failed: 2 + 3 = {result}, expected {expected}")
    sys.exit(1)

# Тест 2: Строки
msg = spike_pybind.greet("VibeCoder")
print(f"✅ Test 2 Output: {msg}")

print("🎉 Day 2 Spike Complete: Python <-> C++ Bridge is working.")
