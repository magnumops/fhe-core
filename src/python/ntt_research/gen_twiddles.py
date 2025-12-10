N = 8
Q = 17
PSI = 3

filename = "twiddles.hex"
print(f"Generating {filename} for N={N}, Q={Q}, PSI={PSI}...")

with open(filename, "w") as f:
    for i in range(N):
        val = pow(PSI, i, Q) # Powers: 3^0, 3^1, ...
        # Формат: @ADDR DATA_IN_HEX
        # hex(val)[2:] убирает префикс '0x'
        f.write(f"@{i:02x} {val:016x}\n")

print("Done.")
