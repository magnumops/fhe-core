import math

N = 4096
# Хардкодим найденные ранее значения для стабильности (Day 8 result)
Q = 1073750017
PSI = 996876704

print(f"Restoring ntt_config_4k.py with Q={Q}, PSI={PSI}")
with open("ntt_config_4k.py", "w") as f:
    f.write(f"N = {N}\n")
    f.write(f"Q = {Q}\n")
    f.write(f"PSI = {PSI}\n")
