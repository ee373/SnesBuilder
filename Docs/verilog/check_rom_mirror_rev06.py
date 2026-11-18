"""Independent recursive reference vs Rev.0.6 equations; no HDL timing."""
def reference(x, blocks):
    if x < blocks:
        return x
    p = 1 << (x.bit_length() - 1)
    return reference(x-p, blocks) if blocks <= p else p+reference(x-p, blocks-p)

def logic(x, n, host_ram=False):
    y = 0
    for i in range(4):
        k = (n >> i) & 1
        k |= any(((n >> j) & 1) and not ((x >> j) & 1) for j in range(i+1,4))
        if i == 0 and host_ram:
            k = 1
        y |= (((x >> i) & 1) & k) << i
    return y

def main():
    for b in range(1,17):
        for x in range(16):
            assert logic(x,b-1) == reference(x,b)
            assert (logic(x,b-1,True) & 1) == (x & 1)
    cases = 0
    for ex in (0,1):
        for b in range(1,17 if ex else 9):
            for bank in range(256):
                x = (8 if ex and not bank & 128 else 0) | ((bank >> 3) & 7)
                assert logic(x,b-1) == reference(x,b)
                cases += 1
    print(f"PASS: 256 ROM combinations, 256 SRAM A19, {cases} bank cases")
if __name__ == "__main__":
    main()
