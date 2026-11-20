# SFCBuilder Rev.0.9 現行仕様の正本

AG32VF407VGT6（RISC-V＋FPGA）を1チップ制御SoCとし、SFCアドレス18本専用入力＋SFC A6～A11の外部バッファ6本、MEMアドレス23本、共通MEMデータ8本を使用する。U1～U4/U6=74LVC245A×5、U5=SN74LVC8T245×1。GPIOは使用・予約77/78、予備1本（[hardware.md](hardware.md)と[pinout.csv](pinout.csv)に従う）。FPGA開発はAGM Supra Nativeを使用する。

| 現行ファイル | 内容 |
|---|---|
| [hardware.md](hardware.md) | SFC→レベル変換→SoC→NOR/SRAMの仕様と主要配線 |
| [pinout.csv](pinout.csv) | AG32VF407VGT6全100物理ピン |
| [level-shifters.md](level-shifters.md) | U1～U6のチャネル・DIR/OE |
| [memory.md](memory.md) | NOR/SRAMのピン接続、ROM形式、容量マスク |
| [bus.md](bus.md) | AHB、所有権、共通MEMデータの調停 |
| [communication.md](communication.md) | `$5000 CPU_CONTROL`、`$5001 COMMAND`以降の13レジスタ、64アドレス窓、FIFO、IRQ |
| [firmware.md](firmware.md) | 内蔵Flash共通ファームウェア（Jet・cmixer16音）・RISC-Vアプリ停止/再開・NOR格納イメージのSRAM実行・SRAM BIOS・電源断退避 |
| [audio.md](audio.md) | cmixer16音＋S-DSP8音、16bit/64kHzステレオPCM・19bit補間・64タップFIR・20×12bit逐次乗算・3次DSM・22kHzアナログLPF |
| [power-cic.md](power-cic.md) | 電源・SRAM保持・CIC・リセット |
| [fpga-development.md](fpga-development.md) | Supra Native、ライセンス、DAP |
| [production.md](production.md) | Rev.0.9 BOM、PCB、販売構想 |
| [roadmap.md](roadmap.md) | 未検証と実装工程、INT16×4 MACストレッチ目標 |
| [prototypes/3d-demo/README.md](prototypes/3d-demo/README.md) | Jetによる3D描画・OS起動ロゴ・Rev.0.9 3Dデモ・USB共通映像方式（**152×104、BG1 8bpp 128px＋CGRAM RGB555 24px、上下各8走査線の強制ブランキング、DMA＋HDMA**）と転送・表示検証 |
| [prototypes/audio-demo/README.md](prototypes/audio-demo/README.md) | 多重PCM・EQ・エフェクト・FIR/3次DSMのデモと音質測定計画 |
| [rom-compatibility.md](rom-compatibility.md) | 既存ROMの互換性 |
| [sdk-emulator.md](sdk-emulator.md) | SDK、エミュレータ、カートリッジ→SFC映像転送の共通経路、USB映像モードと共通の152×104表示・強制ブランキング・DMA/HDMA同期 |
| [references.md](references.md) | 参照資料 |

[verilog](verilog/)と[references/verilog](references/verilog/)の旧RTL、[alternatives](alternatives/)の代替検討は**現行仕様から独立した履歴資料**であり、Rev.0.9に採用しない。新たに合成・実機検証されたRev.0.9 RTLはまだ存在しない。
