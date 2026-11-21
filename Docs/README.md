# SFCBuilder Rev.0.9 — 現行AGM設計ドキュメント

本ディレクトリは **AGM AG32VF407VGT6（AGRV2KL100）** を使用するSFC/SNES拡張カートリッジの現行仕様を扱う。設計の全体像は[アーキテクチャ](architecture/overview.md)で確認する。

## 仕様の管理方法

**一つの仕様項目は一つの正本ファイルで管理する。** 他文書では信号名・容量・レジスタ値・部品ピン番号などの表を重複して転記せず、その正本へリンクする。現在の実装と設計予定は明確に区別する。

AG32 FPGAの実装済み機能については[RTL](../fpga/rtl/)、[ピン・IPのトップ定義](../fpga/top.ve)、[タイミング制約](../fpga/timing.sdc)、[ビルド手順](../fpga/build.ps1)を実装の基準とし、シミュレーション・配置配線の結果は[検証記録](verification/README.md)で管理する。共通ファームウェア、PCB、SFC実機、Jet/cmixer、USB映像、将棋AIはそれぞれの設計・実証状況に従う。

## アーキテクチャ

- [システム構成と仕様境界](architecture/overview.md)：RISC-V／FPGA／SFCの責務、主なクロックとデータ経路を説明する。

## ハードウェア：`hardware/`

| 正本 | 記載項目 |
|---|---|
| [SFC・AG32インターフェース](hardware/interface.md) | SFCエッジ端子、AG32の機能群、FPGAとCPUの接続 |
| [AG32 100ピン割当て](hardware/pinout.csv) | 物理ピン番号、信号、入出力区分 |
| [レベル変換とOE](hardware/level-shifters.md) | U1～U6、方向・出力許可と競合防止 |
| [NOR・SRAM物理配線](hardware/memory-devices.md) | 8 MiBパラレルNOR、128 KiB SRAMとデバイス端子 |
| [セーブストレージ](hardware/save-storage.md) | SPI NORの配線、/CS、128 KiB×2バンクと保存領域 |
| [電源・POWER_FAIL](hardware/power.md) | LDO、HiCAP、充放電経路、比較器と検出しきい値 |
| [CIC・RESET・IRQ](hardware/cic-reset.md) | SFCのリセット、割り込み、SuperCIC |

## FPGA：`fpga/`

| 正本 | 記載項目 |
|---|---|
| [開発・ビルド](fpga/development.md) | AgRV SDK、Prepare LOGIC、Supra Nativeとクロック構成 |
| [AHB・MEMバス](fpga/bus.md) | CPU MMIOアドレス、共通MEM所有権、WRAM待機、NOR BUSY、POWER_FAIL |
| [SFC通信・FIFO・IRQ](fpga/communication.md) | `$5000`系13レジスタ、停止要求、REPLY、FIFO |
| [ROM互換・マッピング](fpga/rom-mapping.md) | HiROM/LoROM/Ex形式、ROM_SIZE、SRAM・BIOS窓 |
| [PCM・FIR・DSM](fpga/audio.md) | 64 kHz PCM、80 MHz FIR、8 MHz 3次DSM、音声出力 |

## ファームウェア：`firmware/`

| 正本 | 記載項目 |
|---|---|
| [起動・BIOS・リンカ](firmware/boot.md) | 内蔵Flash、内蔵SRAM、SFC BIOS、起動順序、GCC/ABI |
| [ゲームパッケージ](firmware/game-package.md) | SFC ROM・RISC-V実行イメージ・リソースのNOR内配置 |
| [アプリ実行・停止](firmware/application.md) | ゲーム固有処理、Jet/cmixer共通ABI、停止・再開 |
| [音声ソフトウェア](firmware/audio-runtime.md) | cmixer、追加DSP、16音、RAM・音源供給 |
| [バックアップ処理](firmware/backup.md) | 電源断退避、2バンク復元、動作継続条件と解除 |

## SDK・実証・検証・製造

- [SDK・エミュレータ・USB](software/sdk-emulator.md)：PVSnesLib、AG32 SDK、エミュレータ拡張と共通映像転送を扱う。
- [3D・152×104表示デモ](prototypes/graphics.md)：Jet、Mode 3、VRAM DMA、CGRAM/BG1VOFS HDMAの実証設計を記載する。
- [追加音声デモ](prototypes/audio-demo.md)：cmixer・PCM・DSM・アナログ音声の試験段階を記載する。
- [将棋AI実証](prototypes/shogi/README.md)：全体設計を示し、[SFC/RISC-V通信](prototypes/shogi/interface.md)、[NNUE配置](prototypes/shogi/nnue.md)、[工程](prototypes/shogi/milestones.md)を参照する。
- [FPGA本番検証](verification/README.md)：合成・STA・RTL試験の結果と、実機未検証の項目を記録する。
- [AHB詳細とタイミング](verification/ahb.md)：バス信号、応答周期、クロック境界、タイミング余裕を記録する。
- [ロードマップ](planning/roadmap.md)：実装完了項目とソフトウェア・実機の次工程を管理する。
- [BOM・製造](planning/production.md)：採用部品、PCB条件、試作・量産計画を管理する。
- [外部参照資料](references.md)：AGM／SFC／現行部品／ライブラリの一次資料を案内する。
