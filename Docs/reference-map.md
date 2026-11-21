# 記載項目別参照表 — Rev.0.9 AGM

旧版の全24ファイルは[old/](old/)に退避し、旧資料の記述内容を項目別に以下の現行正本へ移した。同一仕様が複数ファイルにあった場合は、**新しい正本を一か所に定め、ほかの文書ではリンクのみを保持する。** 旧資料の見出しは追跡用に記す。旧文書は履歴参照であり、現行仕様の競合がある場合は新正本と現行RTLを使用する。

## 分割した旧文書の項目対応

| 分野・仕様項目 | 旧文書の記載箇所 | 新しい正本 |
|---|---|---|
| 全体構成・仕様優先順位・実装済み範囲 | [old/README.md](old/README.md)：正本・実装状況・索引 | [システム全体](architecture/overview.md)、[目次](README.md)、[検証](verification/README.md) |
| SFCエッジ端子、AG32の機能別ピン、CPU/FPGA接続 | [old/hardware.md](old/hardware.md)：SFCエッジ端子、SoCの固定機能、内蔵FPGAとの接続 | [インターフェース](hardware/interface.md) |
| U1～U6・OE・DIR | [old/hardware.md](old/hardware.md)：レベル変換・3SB、[old/level-shifters.md](old/level-shifters.md) | [レベル変換](hardware/level-shifters.md) |
| 100ピン割当て | [old/pinout.csv](old/pinout.csv)、[old/hardware.md](old/hardware.md)：物理ピン概要 | [ピン表CSV](hardware/pinout.csv) |
| NOR/SRAM品種・端子・物理配線 | [old/memory.md](old/memory.md)：デバイス端子表、[old/hardware.md](old/hardware.md)：外部メモリ | [メモリデバイス](hardware/memory-devices.md) |
| 保存用SPI NOR、/CS、バンク配置 | [old/memory.md](old/memory.md)：セーブデータ用256 KiB SPI NOR | [セーブストレージ](hardware/save-storage.md) |
| ROM4形式、ROM_SIZE、SRAM/BIOS窓、互換性計画 | [old/memory.md](old/memory.md)：マッピング概要、[old/rom-compatibility.md](old/rom-compatibility.md) | [ROMマッピング](fpga/rom-mapping.md) |
| MEM所有権、AHB、WRAM待機、NOR BUSY、POWER_FAIL制御 | [old/hardware.md](old/hardware.md)、[old/bus.md](old/bus.md)、[old/memory.md](old/memory.md)：CPU側AHB | [FPGAバス](fpga/bus.md) |
| SFC `$5000`系13レジスタ、FIFO、REPLY、IRQ | [old/communication.md](old/communication.md)、[old/hardware.md](old/hardware.md)：通信概要 | [FPGA通信](fpga/communication.md) |
| AgRV SDK・Prepare LOGIC・Supra Native・ビルド | [old/fpga-development.md](old/fpga-development.md) | [FPGA開発](fpga/development.md) |
| PCM FIFO、FIR、DSM、音声MMIO、アナログLPF | [old/audio.md](old/audio.md)：信号経路・クロック・レジスタ・アナログ・実装測定 | [FPGA音声](fpga/audio.md) |
| cmixer、16音、追加DSP、ソフトウェア音源メモリ | [old/audio.md](old/audio.md)：RISC-Vの音源・DSPとメモリ | [音声ファームウェア](firmware/audio-runtime.md) |
| 電源・HiCAP・電源断比較器・検出しきい値 | [old/power-cic.md](old/power-cic.md)：電源構成・HiCAP・電源断検出、[old/hardware.md](old/hardware.md)：バックアップ接続 | [電源回路](hardware/power.md) |
| SFC /RESET、/IRQ、CIC、テスト端子 | [old/power-cic.md](old/power-cic.md)：SFC制御・CIC | [CIC・リセット](hardware/cic-reset.md) |
| 共通Flash・SFC BIOS・起動順序・リンカ・MMIO API | [old/firmware.md](old/firmware.md)：現在の実装境界、メモリごとの配置、起動、GCC | [起動と共通ファームウェア](firmware/boot.md) |
| ゲームパッケージ・RISC-V SRAM実行イメージのNOR内配置 | [old/memory.md](old/memory.md)：ゲームパッケージ | [ゲームパッケージ](firmware/game-package.md) |
| ゲームアプリ停止再開・ABI・共通Jet/cmixer | [old/firmware.md](old/firmware.md)：共通メディアライブラリとアプリ停止・再開 | [アプリ実行](firmware/application.md) |
| 電源断退避・復元シーケンス・整合性・保持制御 | [old/firmware.md](old/firmware.md)：電源断時のSRAMバックアップ、[old/power-cic.md](old/power-cic.md)：バックアップ動作 | [バックアップ処理](firmware/backup.md) |
| FPGAテスト・配置配線・STA結果 | [old/hardware.md](old/hardware.md)：性能と検証、[old/verification/README.md](old/verification/README.md) | [検証サマリー](verification/README.md) |
| AHBサイクル・クロック境界・タイミング制約詳細 | [old/verification/ahb-interface.md](old/verification/ahb-interface.md) | [AHB詳細](verification/ahb.md) |
| 製造・BOM・PCB、価格仮定 | [old/production.md](old/production.md) | [製造・BOM](planning/production.md) |

## 文書全体を移動したもの

| 旧文書 | 現行文書 | 主な項目 |
|---|---|---|
| [old/level-shifters.md](old/level-shifters.md) | [hardware/level-shifters.md](hardware/level-shifters.md) | 変換ICとOE制御 |
| [old/bus.md](old/bus.md) | [fpga/bus.md](fpga/bus.md) | AHB・共有バス |
| [old/communication.md](old/communication.md) | [fpga/communication.md](fpga/communication.md) | MMIOとSFC通信 |
| [old/fpga-development.md](old/fpga-development.md) | [fpga/development.md](fpga/development.md) | AGM開発手順 |
| [old/rom-compatibility.md](old/rom-compatibility.md) | [fpga/rom-mapping.md](fpga/rom-mapping.md) | ROM形式と互換性 |
| [old/pinout.csv](old/pinout.csv) | [hardware/pinout.csv](hardware/pinout.csv) | 物理100ピン |
| [old/sdk-emulator.md](old/sdk-emulator.md) | [software/sdk-emulator.md](software/sdk-emulator.md) | SDK・USB映像 |
| [old/prototypes/3d-demo/README.md](old/prototypes/3d-demo/README.md) | [prototypes/graphics.md](prototypes/graphics.md) | 3D表示計画 |
| [old/prototypes/audio-demo/README.md](old/prototypes/audio-demo/README.md) | [prototypes/audio-demo.md](prototypes/audio-demo.md) | 音声実証 |
| [old/prototypes/shogi-ai/README.md](old/prototypes/shogi-ai/README.md) | [prototypes/shogi/README.md](prototypes/shogi/README.md) | 将棋AI概要 |
| [old/prototypes/shogi-ai/integration.md](old/prototypes/shogi-ai/integration.md) | [prototypes/shogi/interface.md](prototypes/shogi/interface.md) | 将棋通信 |
| [old/prototypes/shogi-ai/milestones.md](old/prototypes/shogi-ai/milestones.md) | [prototypes/shogi/milestones.md](prototypes/shogi/milestones.md) | 将棋工程 |
| [old/prototypes/shogi-ai/nnue-memory.md](old/prototypes/shogi-ai/nnue-memory.md) | [prototypes/shogi/nnue.md](prototypes/shogi/nnue.md) | NNUE格納 |
| [old/roadmap.md](old/roadmap.md) | [planning/roadmap.md](planning/roadmap.md) | 開発ロードマップ |
| [old/production.md](old/production.md) | [planning/production.md](planning/production.md) | BOM・製造 |
| [old/references.md](old/references.md) | [references.md](references.md) | 外部資料 |
| [old/verification/README.md](old/verification/README.md) | [verification/README.md](verification/README.md) | RTL・STA合否 |
| [old/verification/ahb-interface.md](old/verification/ahb-interface.md) | [verification/ahb.md](verification/ahb.md) | AHB検証詳細 |

原文を分割した対象は`hardware.md`、`memory.md`、`power-cic.md`、`firmware.md`、`audio.md`と、全体索引の`README.md`である。これらは上表の項目ごとに新しいファイルへ移し、重複する端子・マップ・電源・試験数値については新正本への参照へ変更した。
