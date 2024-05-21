#!/usr/bin/python3

out = []
for i in range(64):
    bit_1 = i & 1
    bit_2 = (i & 4) >> 2
    bit_3 = (i & 8) >> 3
    bit_4 = (i & 32) >> 5
    lfsr_next_value = bit_1 ^ bit_2 ^ bit_3 ^ bit_4
    out.append(str(lfsr_next_value))

print(', '.join(out))
    