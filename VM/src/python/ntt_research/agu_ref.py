import math

N = 8
logN = int(math.log2(N))

print(f"Generating AGU Trace for N={N} (Iterative Radix-2 DIT)...")

# Формат вывода: STAGE | U_ADDR | V_ADDR | W_ADDR
# W_ADDR - это индекс поворотного множителя.
# В DIT на стадии s (от 1 до logN), длина блока m = 2^s.
# Поворотный множитель w_m = exp(-2pi i / m).
# W меняется внутри блока.

# Для простоты реализации в железе часто используют заранее вычисленную таблицу W.
# В Stage 1 (m=2) нужен W_2^0 = 1. (Addr 0 in full table if mapped correctly)
# Давайте используем простую схему адресации W:
# W_idx = j * (N / m)  <-- стандартная формула для отображения на полную таблицу N.

trace = []

for s in range(1, logN + 1):
    m = 1 << s      # Размер блока: 2, 4, 8
    half_m = m >> 1 # Половина: 1, 2, 4
    
    # stride для W. 
    # На последнем этапе (m=N) шаг должен быть 1.
    # На первом этапе (m=2) шаг должен быть N/2 = 4.
    w_stride = N // m 
    
    print(f"--- Stage {s} (m={m}, gap={half_m}) ---")
    
    # Проход по блокам
    for k in range(0, N, m):
        # Проход внутри бабочки
        for j in range(half_m):
            u_idx = k + j
            v_idx = k + j + half_m
            w_idx = j * w_stride
            
            trace.append((u_idx, v_idx, w_idx))
            print(f"BF: U={u_idx}, V={v_idx}, W_addr={w_idx}")

# Сохраняем эталон для теста
with open("agu_trace.txt", "w") as f:
    for t in trace:
        f.write(f"{t[0]} {t[1]} {t[2]}\n")
