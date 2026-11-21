# Rev.0.9 — システムアーキテクチャと実装境界

SFCBuilderは、SFCのメモリバスへ接続する **AGM AG32VF407VGT6（RV32IMAFC + FPGA）** 拡張カートリッジである。制御SoCはAG32一つとし、外部8 MiBパラレルNOR、128 KiB SRAM、256 KiB SPI NOR、USB Full-Speed、microSD、ステレオ追加音声を備える。SFC用65C816プログラムとRISC-Vプログラムは別の実行領域を持つ。

## 構成要素と責務

| 要素 | 主要な役割 | 詳細の正本 |
|---|---|---|
| SFC 65C816／PPU／S-DSP | ゲームROM実行、入出力、VRAM・CGRAM描画、標準8音 | [SFC接続](../hardware/interface.md)、[表示経路](../prototypes/graphics.md) |
| AG32内蔵FPGA | 通常ROMの非同期マッピング、NOR/SRAM制御、MEM所有権、起動応答、AHB、通信、PCM/FIR/DSM | [バス](../fpga/bus.md)、[ROM](../fpga/rom-mapping.md)、[通信](../fpga/communication.md)、[音声](../fpga/audio.md) |
| AG32 RISC-V（RV32IMAFC） | 内蔵Flashの共通制御、起動ローダ、USB／SPI、ゲーム固有の演算・音声プログラム | [起動](../firmware/boot.md)、[アプリ](../firmware/application.md) |
| 8 MiBパラレルNOR／128 KiB SRAM | ROM・ゲームリソースと共有データ、SFC BIOS、セーブデータ | [物理配線](../hardware/memory-devices.md)、[ゲームパッケージ](../firmware/game-package.md) |
| 256 KiB SPI NOR／HiCAP | 電源断時の外部SRAM先頭120 KiBの二重化保存 | [媒体](../hardware/save-storage.md)、[回路](../hardware/power.md)、[退避処理](../firmware/backup.md) |

## クロックとデータ経路

本番のクロック設定はRISC-V SYSCLK **240 MHz**、FPGA BUSCLKおよびFIR **80 MHz**、水晶由来DSM **8 MHz**、USB用PLL **60 MHz** とする。FPGAのAHBは240 MHzと80 MHzの境界で要求・応答を受け渡し、NOR・SRAMの8 bitサイクルへの変換を行う。詳細な制約・検証値は[AHB検証](../verification/ahb.md)を正本とする。

SFCの通常ROM読出しは**FPGAのアドレス変換→外部NOR**で完結し、RISC-Vの命令実行やAHBトランザクションを毎読出しで行わない。RISC-VがNOR/SRAMを操作するときはAHBからFPGAへ要求し、SFCとCPUでMEMバス所有権を排他的に切り替える。CPU所有中の65C816はWRAM内で待機し、返却IRQ後にカートリッジへのアクセスを再開する。[U1/U6の排他](../hardware/level-shifters.md)、[バス所有権](../fpga/bus.md)がこの経路を規定する。

起動時には内蔵Flashの共通ファームウェアが外部SRAM末尾8 KiBへSFC BIOSを展開し、FPGAの固定起動応答から`JML $2F6000`へ進む。ゲーム固有のRISC-VイメージはNORからAG32内蔵SRAMへ展開して実行する。[起動順序](../firmware/boot.md)と[ゲーム配置](../firmware/game-package.md)を参照する。

追加音声はRISC-Vの64 kHz・16 bitステレオPCMをFPGA FIFO→80 MHz FIR（320 kHz・17 bit）→8 MHzの3次1 bit DSM→外部LPF→SFC AUDIO L/Rとして伝送する。[FPGA音声](../fpga/audio.md)と[音源処理](../firmware/audio-runtime.md)を参照する。3D/USB映像はRISC-Vで生成・受信した素材を外部共有SRAMへ渡し、65C816のDMA/HDMAを介してPPUへ表示する設計であり、FPGAからPPUを直接駆動しない。

## 実装済みと未実証の区分

**RTLおよび配置配線が確認済みなのはFPGAのバス・ROM制御・AHB・FIFO・音声経路である。** CPU共通ファームウェア、SFC BIOS、基板・電源、セーブの実機保持時間、ROM互換、Jet/cmixer、USB表示、将棋AIの実証は別工程である。現行の検証数値と残項目は[検証記録](../verification/README.md)、実装工程は[ロードマップ](../planning/roadmap.md)を参照する。
