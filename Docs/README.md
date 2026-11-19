# SFCBuilder Rev.0.9 現行仕様の正本

AG32VF407VGT6（RISC-V＋FPGA）を1チップ制御SoCとし、SFCアドレス18本専用入力＋SFC A6～A11の外部バッファ6本、MEMアドレス23本、共通MEMデータ8本を使用する。U1～U4/U6=74LVC245A×5、U5=SN74LVC8T245×1。GPIOは使用・予約75/78、予備3本。FPGA開発はAGM Supra Nativeを使用する。

| 現行ファイル | 内容 |
|---|---|
| [hardware.md](hardware.md) | SFC→レベル変換→SoC→NOR/SRAMの仕様と主要配線 |
| [pinout.csv](pinout.csv) | AG32VF407VGT6全100物理ピン |
| [level-shifters.md](level-shifters.md) | U1～U6のチャネル・DIR/OE |
| [memory.md](memory.md) | NOR/SRAMのピン接続、ROM形式、容量マスク |
| [bus.md](bus.md) | AHB、所有権、共通MEMデータの調停 |
| [communication.md](communication.md) | 64アドレス通信窓、FIFO、IRQ |
| [firmware.md](firmware.md) | RISC-Vローダ・SRAM BIOS・ブート |
| [audio.md](audio.md) | DAC0/1とステレオ音声 |
| [power-cic.md](power-cic.md) | 電源・SRAM保持・CIC・リセット |
| [fpga-development.md](fpga-development.md) | Supra Native、ライセンス、DAP |
| [production.md](production.md) | Rev.0.9 BOM、PCB、販売構想 |
| [roadmap.md](roadmap.md) | 未検証と実装工程 |
| [rom-compatibility.md](rom-compatibility.md) | 既存ROMの互換性 |
| [sdk-emulator.md](sdk-emulator.md) | SDK、USB連携、エミュレータ |
| [references.md](references.md) | 参照資料 |

[verilog](verilog/)と[references/verilog](references/verilog/)の旧RTL、[alternatives](alternatives/)の代替検討は**現行仕様から独立した履歴資料**であり、Rev.0.9に採用しない。新たに合成・実機検証されたRev.0.9 RTLはまだ存在しない。
