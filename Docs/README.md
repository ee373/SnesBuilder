# SFCBuilder

スーパーファミコン向けARMコプロセッサ搭載開発カートリッジの設計資料。

- **現行設計リビジョン：Rev0.8**
- 資料更新：2026-11-19
- 開発状況：回路・論理設計段階。AG256合成・フィッティング、PSoC Creator配置・実機FastROM検証は未完了。

## 概要

SFCBuilderは、8MiB NOR Flash、128KiBバックアップSRAM、ARM Cortex-M3を内蔵するPSoC 5LP、AG256SL100 CPLD、8bit双方向レベル変換IC×1と8bit片方向レベル変換IC×5を搭載する。SFCの65C816、PPU、SPC700/S-DSPを使用しながら、ARMの演算、共有SRAM、USB Full-Speed、microSD、追加モノラルPCM音声を利用できる。

AG256は74LVC245Aで3.3Vに変換されたSFCアドレス/制御信号を受け、NOR・SRAMの高速アドレスと/CE・/OE・/WEを一元生成する。SN74LVC8T245DBRはSFCデータ8bitを双方向変換し、74LVC245APW,118の5個はアドレス・制御・microSDへの片方向変換を担当する。PSoCのSFCデータポートP0はSFCバスに直接接続するため、ARMが共有MEMを使用していても$5000のコマンド・FIFO通信は継続できる。

HiROM、ExHiROM、LoROM、ExLoROMを対象とし、128KiB～8MiBの2冪7段階はAG256のハードウェア容量ミラーを使用する。3MiBなど非2冪容量だけARMローダがNORへ事前展開する。SlowROM 200ns以内を必須、FastROM 120ns以内を設計目標とする。専用拡張チップの動作互換は個別実装対象であり標準機能には含めない。

最初の統合検証ではPVSnesLibで作成したHiROM/SlowROMの最小プログラムをNORから起動し、$5000通信、SRAM、CPLDのROMモード切替、FastROMへ段階的に拡張する。

## 現行仕様の正本

| 文書 | 内容 |
|---|---|
| [hardware.md](hardware.md) | 主要部品、電源、PSoCポート、バス構成 |
| [cpld.md](cpld.md) | AG256の54 I/O予算、6個の8bit変換IC、DIR/OE、SFC/MEMの配線契約 |
| [pinout.csv](pinout.csv) | PSoC TQFP-100全端子の再配置（使用71/72本） |
| [cpld-pinout.csv](cpld-pinout.csv) | AG256 LQFP100の物理54 I/O候補 |
| [verify_rev08_interfaces.py](verify_rev08_interfaces.py) | 100/54ピン配置と7段階容量マスクの静的チェック |
| [memory.md](memory.md) | NOR、SRAM、4種類のROM形式、7段階容量マスク、非2冪容量の事前展開、ブート6バイト |
| [bus-udb.md](bus-udb.md) | 排他バス所有権、CPLD High-Z、UDB通信、STA条件 |
| [communication.md](communication.md) | $5000通信、FIFO、DMA、SFC/ARM協調、音源・USB実行時通信 |
| [firmware.md](firmware.md) | BIOS、ゲームローダ、ARMプログラム、USB・microSD、セーブ |
| [rom-compatibility.md](rom-compatibility.md) | 既存ROMのマップ、2冪7段階のハードウェアミラー、非2冪容量のNOR事前展開 |
| [power-cic.md](power-cic.md) | 5V/3.3V、SRAM電池保持、リセット/CIC、電源安全性 |
| [audio.md](audio.md) | PSoC DVDAC、MCP6001、外部音声L/R |
| [production.md](production.md) | 現行BOM、1枚・100枚製作原価、試作・量産費 |
| [udb-evaluation.md](udb-evaluation.md) | UDB/CPLD資源予算、検証範囲 |
| [sdk-emulator.md](sdk-emulator.md) | SDK、ツールチェーン、エミュレータ |
| [roadmap.md](roadmap.md) | 詳細設計・合成・STA・実機・デモの検証計画 |
| [references.md](references.md) | 採用部品、SFCバス、PSoCの技術資料 |
| [verilog/README.md](verilog/README.md) | HDL検証資料の位置づけと現行RTLの進捗 |

## 起動とソフトウェア

SFC起動BIOSはPSoC内蔵Flashから共有SRAM末尾8KiBへ展開する。リセット解除時にPSoC UDBが$00:FFFC/$00:FFFDと$00:8000–8003の6バイト固定値を返し、`JML $2F6000`でSRAM BIOSへ移行する。ゲームロード時にPSoCがSFC /RESETを保持し、外部MEMバス所有権とCPLDモードを設定する。SRAM BIOSは$5000通信からARMへ処理を要求し、WRAM上の切替コードを通じてゲームROMへ移行する。

USBはPSoCがFull-Speed USBデバイス、PC/Raspberry Piがホストとして動作する。ゲーム実行時の画像・音声・コントローラ情報の転送、ARM演算、SFC表示・音源との協調をソフトウェア開発対象とする。

## 仕様確定の基準

Rev0.8で選定した部品と2026-11-19の再配置案を本資料に記載する。SFC A0–A3をPSoC P3[0:3]へ接続、P0をSFCデータ、P5をMEMデータとし、SFC /RESETはPSoC P15[1]へ直接接続する。UDB通信は16アドレス（実装12）を使用する。AG256の256 LUT・54 I/Oへの実フィッティング、PSoCの71/72 I/O・SIO・アナログルートのCreator適合、8T245の5V側入力HIGH条件、FastROM 120nsの達成、/RESETの電気的な制御とメモリバスの競合防止は合成・実機検証で確定する。各評価で不一致が生じた場合は、[hardware.md](hardware.md)、[cpld.md](cpld.md)、[memory.md](memory.md)、[bus-udb.md](bus-udb.md)の関連記述を同一変更で更新する。
