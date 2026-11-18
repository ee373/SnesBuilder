#!/usr/bin/env python3
"""Exhaustive independently calculated checks of 1MiB mapper bit-equations.
The Verilog simulation is separate: run `iverilog -g2012 -s tb_rom_mirror_1m -o sim rom_mirror_1m.v tb_rom_mirror_1m.v && vvp sim`.
"""
from itertools import product

def mirror(x, count):
    # Repeated mirrored blocks repeat per the next-power-of-two window.
    window = 1 << (count-1).bit_length()
    x &= window-1
    if count & (count-1) == 0:
        return x
    power = 1 << (count.bit_length()-1)
    return x if x < power else power + mirror(x-power, count-power)

def rtl(a19,a20,a21,a23,ex,n):
    x2=(1-a23)&ex; x1=a21; x0=a20
    n0=n&1; n1=(n>>1)&1; n2=(n>>2)&1
    y2=x2&n2
    y1=x1&(n1 | (n2 & (1-x2)))
    y0=x0&(n0 | (n1 & (1-x1)) | (n2 & (1-x2)))
    return (y2<<3)|(y1<<2)|(y0<<1)|a19

cnt=0
for ex in range(2):
    for blocks in range(1,9 if ex else 5):
        for a23,a21,a20,a19,ram in product(range(2),repeat=5):
            got=rtl(a19,a20,a21,a23,ex,blocks-1)
            x=(((1-a23)&ex)<<2)|(a21<<1)|a20
            expected=(mirror(x,blocks)<<1)|a19
            assert got == expected, (ex,blocks,a23,a21,a20,a19,ram,got,expected)
            cnt+=1
print('PASS: ',cnt, 'independent mapper and SRAM-A19 cases')
for blocks in range(1,9):
    print(f'{blocks}MiB: '+ ' '.join(map(str,(mirror(x,blocks) for x in range(8)))))
