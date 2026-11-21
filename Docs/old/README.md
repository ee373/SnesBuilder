# SFCBuilder Rev.0.9 — AGM AG32VF407VGT6 現行仕様

SFCBuilderはSFC/SNES用のRISC-V＋FPGA拡張カートリッジである。**現行ハードウェアはAGM AG32VF407VGT6（AGRV2KL100、LQFP100）を唯一の制御SoCとする。** RISC-Vが起動・ローダ・USB・microSD・ゲーム固有処理を担当し、内蔵FPGAがSFC側ROMマッピング、外部MEM調停、AHB、通信レジスタ、音声出力を担当する。SFCの通常ROM読出しにRISC-Vのソフトウェア処理は介在しない。

## 正本と実装状態

本ディレクトリはRev.0.9の設計と検証状況を記録する。**実装済みのFPGA動作**については[現行RTL](../fpga/rtl/)、[top.ve](../fpga/top.ve)、[timing.sdc](../fpga/timing.sdc)、[本番ビルド](../fpga/build.ps1)を優先し、物理100ピン割当ては[pinout.csv](pinout.csv)、STAとテストベンチの合否は[検証記録](verification/README.md)で確認する。基板配線、共通ファームウェア、SFC BIOS、SDK、ゲーム別ソフトウェア、3D/USB表示は、RTLの完成とは独立した設計・実証対象である。

| 領域 | Rev.0.9の構成 | 実装・検証状況 |
|---|---|---|
| CPU・クロック | RV32IMAFC。本番SYSCLK 240 MHz、FPGA BUSCLK・FIR 80 MHz、HSE由来DSM 8 MHz、USB用PLL 60 MHz | FPGA本番構成として合成・配置配線・STA済み。CPUの型番上限248 MHzは本番設定値ではない |
| SoC／SFC端子 | AG32VF407VGT6、SFCアドレス専用入力18本とU1経由6本、外付けU1～U6レベル変換 | ピン定義・バス制御RTLは実装済み。PCB上の電気特性は未測定 |
| 共通パラレルMEM | 8 MiB・x8・70 ns NOR、128 KiB・55 ns SRAM、MEM A0～A22と双方向D0～D7 | FPGAのROM4形式・容量マスク・所有権制御・CPU側AHBを実装、RTL試験済み。SlowROM/FastROM実機試験は未完了 |
| CPU側MMIO | 制御 `0x60000000～0x6000000C`、通信 `0x60001000～0x60001030`、音声 `0x60002000～0x60002008`、NOR `0x61000000～0x617FFFFF`、SRAM `0x62000000～0x6201FFFF` | 32 bit AHBブリッジ・8 bit MEM展開・エラー応答をRTL検証済み |
| SFC通信 | `$5000～$5FFF`に64アドレス周期でミラーする13レジスタ、各方向4バイトFIFO、IRQ、アプリ停止要求 | FPGA実装済み。CPU側の停止・復帰処理とゲーム用コマンド実装は未完了 |
| 音声 | 64 kHz・16 bitステレオPCM、80 MHzの5相FIR、320 kHz・17 bit、8 MHzの左右独立3次1 bit DSM、PIN29/30 | PCM FIFO・FIR・DSMはRTL検証・配置配線済み。cmixer統合とSFC音声端子のアナログ実測は未完了 |
| ストレージ・I/O | microSDと独立256 KiB SPI NORがSPI0を共有。USB Full-Speed、UART0、SWDを使用 | SPI /CS選択デコーダはRTL実装済み。USB・microSD・保存用ファームウェアは統合前 |
| 電源断セーブ | 5 V→3.3 V、HiCAP 5.5 V・1 F、POWER_FAIL入力、外部SRAM先頭120 KiBをSPI NORの128 KiB×2バンクで保存 | FPGA側のPOWER_FAIL保持とバス制御をRTL検証済み。電源断ファームウェア・保持時間は実機未検証 |
| SFC BIOS・アプリ | SRAM末尾8 KiBのBIOS、内蔵Flashの共通ファームウェア、NORから内蔵SRAM 128 KiBへ展開するゲーム固有RISC-Vコード | 起動固定応答とBIOS窓はFPGA実装済み。BIOS・共通ローダ・ABIは設計仕様 |
| 3D・USB映像・将棋AI | 152×104論理画像、Jet、cmixer、RISC-V将棋AI・NNUE | ソフトウェア／SFC表示の実証計画。完成済み機能として扱わない |

2026-11-20の採用配置配線は、最悪セットアップ余裕 **+0.220 ns**、最悪ホールド余裕 **+0.080 ns**、配置1,934 / 2,112スライスである。この数値はチップ内部の制約に対するもので、SFCエッジからNOR、基板のOE・電源・アナログ出力を含む実機の合否は[検証記録](verification/README.md)の残項目に従う。

## 起動・バス所有権の基準動作

リセット時の`MAP_CONFIG`は`0x28`で、FPGAはSFC /RESETを保持してCPUへ外部MEMを割り当てる。RISC-Vは外部SRAM物理`0x1E000～0x1FFFF`へ8 KiBのSFC BIOSを置き、`BOOT_CONTROL=0x03`に設定する。起動固定応答`$00:FFFC/FFFD = 00/80`と`$00:8000～8003 = 5C/00/60/2F`により、65C816は`JML $2F6000`でBIOSへ移行する。SFC稼働中にCPUが共通MEMを使用するには、65C816側がWRAMで待機し、`$5004`から貸出を要求し、返却IRQを受けてからカートリッジ参照を再開する。NOR BUSY中の返却とPOWER_FAIL時の退避は[バス仕様](bus.md)に従う。

## ハードウェア・FPGAの文書

- [hardware.md](hardware.md)：AG32の物理ピン、SFCエッジ、MEM・周辺回路の接続。
- [pinout.csv](pinout.csv)：AG32物理100ピン割当ての正本。
- [level-shifters.md](level-shifters.md)：U1～U6、OE・DIR、共有MEM所有権。
- [memory.md](memory.md)：8 MiB NOR／128 KiB SRAM、ROM4形式、SPI NOR二重バンク。
- [bus.md](bus.md)：AHBメモリマップ、共有MEM調停、WRAM待機、起動・POWER_FAIL。
- [communication.md](communication.md)：SFC `$5000`系レジスタ、FIFO、IRQ、REPLY。
- [audio.md](audio.md)：本番80 MHz FIR・8 MHz DSM、PCM MMIO、アナログ出力。
- [power-cic.md](power-cic.md)：電源・HiCAP・セーブ退避・CIC。
- [fpga-development.md](fpga-development.md)：AGM Supra Native／AgRV SDK、生成トップと再ビルド。
- [verification/README.md](verification/README.md)：現行ビルドのRTL試験とSTA結果。
- [verification/ahb-interface.md](verification/ahb-interface.md)：AHBクロック境界・応答周期・制約。

## ソフトウェア・試作・製造の文書

- [firmware.md](firmware.md)：共通ファームウェア、RISC-V SRAM実行、SFC BIOS、セーブ。
- [rom-compatibility.md](rom-compatibility.md)：ROM形式・容量ミラーと互換性試験。
- [sdk-emulator.md](sdk-emulator.md)：SDK、エミュレータ、152×104のUSB／3D共通表示。
- [prototypes/3d-demo/README.md](prototypes/3d-demo/README.md)：Jetと65C816／PPU表示の実証計画。
- [prototypes/audio-demo/README.md](prototypes/audio-demo/README.md)：cmixer・DSP・実機音声の実証計画。
- [prototypes/shogi-ai/README.md](prototypes/shogi-ai/README.md)：将棋AIの概要。 [通信仕様](prototypes/shogi-ai/integration.md)、[工程](prototypes/shogi-ai/milestones.md)、[NNUEメモリ](prototypes/shogi-ai/nnue-memory.md)を含む。
- [roadmap.md](roadmap.md)：RTL完了範囲と残る実機・ソフトウェア工程。
- [production.md](production.md)：Rev.0.9のBOM・PCB・量産前の確認項目。
- [references.md](references.md)：AGM、SFC、現行部品・開発ツールの参照資料。
