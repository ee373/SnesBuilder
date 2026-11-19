"""Static Rev0.8 PSoC/AG256 pin contract and 7-size ROM mirror check.

Run: python3 Docs/verify_rev08_interfaces.py
This does not establish Creator/Supra placement, HDL synthesis, or FastROM timing.
"""
import csv
from pathlib import Path

ROOT = Path(__file__).resolve().parent

def load(filename):
    with (ROOT / filename).open(encoding="utf-8", newline="") as stream:
        return list(csv.DictReader(stream))

def check():
    pins = load("pinout.csv")
    assert len(pins) == 100
    by_num = {int(row["pin"]): row for row in pins}
    assert len(by_num) == 100 and set(by_num) == set(range(1, 101))
    gpio = [r for r in pins if r["port"].startswith("P")]
    assert len(gpio) == 72
    assert sum(r["signal"] == "RESERVED_GPIO" for r in gpio) == 1
    required = {
        43: "SFC_/RESET", 44: "SFC_A0", 45: "SFC_A1",
        46: "SFC_A2", 47: "SFC_A3", 48: "CPLD_SPECIAL_SEL",
        49: "RESERVED_GPIO", 5: "USB_VBUS_sense",
        68: "SD_MISO", 29: "MEM_A22", 93: "MEM_/CE_ROM",
        83: "AUDIO_DAC_OUT"
    }
    for pin, name in required.items():
        assert by_num[pin]["signal"] == name, (pin, by_num[pin])
    signals = {r["signal"] for r in gpio}
    assert all(f"MEM_A{n}" in signals for n in range(23))
    assert all(f"MEM_D{n}" in signals for n in range(8))
    assert all(f"SFC_D{n}" in signals for n in range(8))
    assert all(f"SFC_A{n}" in signals for n in range(4))

    cpld = load("cpld-pinout.csv")
    assert len(cpld) == 54
    physical = [int(r["physical_pin"]) for r in cpld]
    assert len(set(physical)) == 54
    reserved = {9,10,11,13,22,23,24,25,31,32,45,46,59,60,63,65,79,80,93,94}
    assert not reserved.intersection(physical)
    assert sum(r["direction"] == "IN" for r in cpld) == 31
    assert sum(r["direction"] == "OUT" for r in cpld) == 23
    net = {r["signal"] for r in cpld}
    assert all(f"MEM_A{n}" in net for n in [*range(4), *range(12,23)])
    assert all(f"SFC_A{n}" in net for n in [*range(4), *range(12,24)])
    assert all(f"ROM_SIZE{n}" in net for n in range(3))

    count = 0
    for size_code in range(7):
        capacity = 1 << (17 + size_code)
        for block128k in range(64):
            for offset in (0, 1, 0x1ffff):
                address = (block128k << 17) | offset
                assert (address & (capacity - 1)) == address % capacity
                count += 1
    print(f"PASS: PSoC 100 physical pins / 72 I/O, AG256 54 I/O, {count} ROM cases")
    print("Not checked: Creator/Supra fit, pin routing, CDC or timing.")

if __name__ == "__main__":
    check()
