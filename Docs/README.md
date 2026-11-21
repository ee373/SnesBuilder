# SFCBuilder Rev.0.9 — AGM AG32VF407VGT6 現行仕様

SFCBuilderはSFC/SNES用のRISC-V＋FPGA拡張カートリッジである。現行構成は **AGM AG32VF407VGT6（AGRV2KL100）**、8 MiBパラレルNOR、128 KiB外部SRAM、256 KiBセーブ用SPI NOR、USB Full-Speed、microSD SPI、追加ステレオ音声、外付けバス変換ICで構成する。現行実装の基準はAGM向けのFPGAプロジェクトと配置配線検証記録とする。

## 仕様の優先順位と実装状態

仕様書間で記述が異なる場合、**AG32向けの実装については [fpga/rtl](../fpga/rtl/) と [fpga/top.ve](../fpga/top.ve) および [fpga/timing.sdc](../fpga/timing.sdc) を優先**する。RISC-Vのゲームローダ、BIOS、SDK、実機未検証の周辺回路は本ディレクトリの設計仕様を基準とする。実装済みRTLの機能と、ソフトウェア・基板・音響を含む製品全体の完成は区別する。

| 対象 | 現行値／状態 |
|---|---|
| CPU | RV32IMAFC、**本番ビルド240 MHz**（型番仕様上の最大値248 MHz） |
| FPGAバス・FIR | **80 MHz** |
| DSM | **8 MHz**、水晶基準 |
| SFCアドレス | 専用入力18本＋U1の外付け6本 |
| MEMアドレス／データ | 23 bit／双方向8 bit。U1・U6で所有権を切替 |
| FPGAバス・AHB・FIFO・ROM制御 | 現行RTLが存在し、シミュレーション・Supra Nativeの配置配線・STAを実施 |
| FPGAステレオ音声 | 64 kHz・16 bit PCM、80 MHzポリフェーズFIR、320 kHz・17 bit、8 MHz 3次1 bit DSM。RTL検証・配置配線済み |
| 配置配線結果 | 2026-11-20時点、最小セットアップ **+0.220 ns**、最小ホールド **+0.080 ns**。条件は検証文書を参照 |
| 基板・FastROM・アナログ音声 | 実機検証前。STA結果だけで外部基板上の成立を保証しない |
| 共通ファームウェア・Jet・cmixer・SFC BIOS | ソフトウェアの設計仕様。完成済みの統合ファームウェアとしては扱わない |
| 152×104映像・USB転送・将棋AI | ソフトウェア／表示の実証計画 |

## ハードウェア・FPGA

- [hardware.md](hardware.md)：AG32VF407VGT6、SFC接続、NOR/SRAM、レベル変換と電源。
- [pinout.csv](pinout.csv)：100ピンの割当て正本。実際のFPGA入出力は [fpga/top.ve](../fpga/top.ve) と対照する。
- [level-shifters.md](level-shifters.md)：U1～U6の方向と出力許可、A6～A11の所有権。
- [memory.md](memory.md)：8 MiB NOR／128 KiB SRAM、ROMマッピング、セーブ用256 KiB SPI NOR。
- [bus.md](bus.md)：MEM所有権、AHBアドレス、WRAM待機、NOR BUSY、POWER_FAIL。
- [communication.md](communication.md)：SFC $5000系13レジスタ、RISC-V側MMIO、4バイトFIFO、IRQ。
- [audio.md](audio.md)：**本番実装の80 MHzポリフェーズFIR**と8 MHz DSM、PCM MMIO、アナログ段。
- [power-cic.md](power-cic.md)：5 V→3.3 V、電源断検出と二重セーブ、CIC。
- [fpga-development.md](fpga-development.md)：Supra Native・AgRV SDK・ビルド・デバッグ。
- [verification/README.md](verification/README.md)：現行本番ビルドの検証一覧。
- [verification/ahb-interface.md](verification/ahb-interface.md)：AHB周期とタイミング数値。

## ソフトウェア・製造

- [firmware.md](firmware.md)：共通ファームウェア、SRAM実行アプリ、BIOS起動、電源断処理。
- [rom-compatibility.md](rom-compatibility.md)：HiROM／LoROM／Ex形式と互換性検証。
- [sdk-emulator.md](sdk-emulator.md)：SDK、エミュレータ、USB／3D共通のSFC映像転送。
- [prototypes/3d-demo/README.md](prototypes/3d-demo/README.md)：Jetを使用した152×104の描画・表示検証。
- [prototypes/audio-demo/README.md](prototypes/audio-demo/README.md)：cmixerと既存FPGA音声RTLの結合・音響測定。
- [prototypes/shogi-ai/README.md](prototypes/shogi-ai/README.md)：RISC-V将棋AI・NNUE検証。
- [roadmap.md](roadmap.md)：実装済み・未実装と次の実機検証。
- [production.md](production.md)：Rev.0.9のBOM、PCB、製造計画。
- [references.md](references.md)：現行部品・ツールとSFC資料。

旧アーキテクチャの実験資料と現在採用していないRTLは現行Docsから削除した。変更履歴はGitコミットで参照する。
