# SFCBuilder 1MiB ROM mapper — verification package

- `rom_mirror_1m.v`: proposed host ROM address mapper for 1MiB-granularity mirror.
- `tb_rom_mirror_1m.v`: self-checking Verilog testbench covering all valid 1–4MiB HiROM and 1–8MiB ExHiROM sizes, both SFC A23 polarities, A21/A20/A19 inputs, and both RAM select values (384 cases).
- `check_1m.py`: independently calculated software oracle, executing the same 384 cases and printing expected mirror sequences.
- `verification.txt`: actually executed verification output.

Run Python check: `python3 check_1m.py`

Run HDL simulation on a system with Icarus Verilog:

```sh
iverilog -g2012 -s tb_rom_mirror_1m -o sim rom_mirror_1m.v tb_rom_mirror_1m.v
vvp sim
```

NOTE: Icarus Verilog was unavailable in the execution environment.  The Verilog testbench has been provided but has **not** been executed or compile-checked here.  The Python independent mapper check has been executed successfully.  The verification files have now been imported into the SFCBuilder Rev.0.7 development branch; main remains unchanged.

## Integration details

- Connect SFC_A19 to SN74LVC16244 channel input pin 33 and its output pin 16 to MEM_A19 / PSoC P1[5]; keep the shared /3OE bus-ownership control.
- PSoC P4[5] (pin 83) becomes the candidate analog audio output (subject to PSoC Creator routing verification).
- In ARM ownership, disable 3SB and drive MEM_A19 from P1[5] GPIO; other memory address pins similarly use bypass.
- NOR bank size is 1MiB; `rom_blocks_m1 = ROM size in MiB - 1`.
- For HiROM the only valid `rom_blocks_m1` values are 0..3; ExHiROM accepts 0..7.
- The existing `sfcbuilder_bridge.v` is an old Rev.0.5 prototype and is not part of this Rev.0.7 mapper verification.
- No checks of SFC cycle timing, actual pad routing/analog route, SRAM decoding or register FIFOs are implied by the stand-alone mapper test.
