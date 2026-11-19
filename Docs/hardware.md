# ハードウェア基本仕様

Rev.0.8 / 2026-11-19（AG256・8bitレベル変換構成へ更新）。採用回路の接続方針。AGM/PSoCの合成・配置・STA・実機確認は未完了。

## 1. 基本構成

| 項目 | 採用仕様 |
|---|---|
| 対応機種 | スーパーファミコン / SNES |
| メインMCU | Infineon PSoC 5LP CY8C5287AXI-LP095、ARM Cortex-M3 最大80MHz |
| MCU内蔵メモリ | Flash 256KiB / SRAM 64KiB / EEPROM 2KiB |
| PSoC UDB | 24 UDB、48 PLD、192マクロセル、24データパス |
| CPLD | **AGM AG256SL100**、256 LUT/LE、80 I/O、LQFP-100、3.3V |
| 双方向データ変換 | **SN74LVC8T245DBR ×1**、8bit、VCCA=3.3V/VCCB=5V、SSOP-24 |
| 片方向アドレス・制御変換 | **Nexperia 74LVC245APW,118 ×5**、8bit、3.3V駆動、5V許容入力、TSSOP-20 |
| 外部ROM | S29GL064S70TFI023、8MiB、x8、70ns、3.3V |
| 外部RAM | CY62128EV30LL-45SXI、128KiB、45ns、3.3V、電池バックアップ |
| ROM形式 | HiROM、ExHiROM、LoROM、ExLoROM |
| ROMミラー | ローダによるNORイメージ事前展開 |
| ROMアクセス目標 | SlowROM 200ns以内必須、FastROM 120ns以内は設計目標 |
| SFC側バス | 5Vアドレス24bit、データ8bit |
| 共通MEMバス | 3.3Vアドレス23bit、データ8bit、SFC/ARM排他所有 |
| CPU間通信 | $5000–$5FFFの32アドレス、双方向4byte FIFO、DMA・IRQ |
| 記録媒体・USB | microSD（SPI）、USB Full-Speed 12Mbpsデバイス |
| 追加音声 | PSoC DVDAC→LPF→MCP6001→SFC外部音声L/R |
| CIC | PIC12F629、SuperCIC Key想定 |
| PCB・試作 | 4層1.2mm、ENIG、外部リードIC、手はんだ |

8MiB NORをゲーム・リソースに使用し、SFC BIOSはPSoC内蔵Flashから共有SRAM末尾8KiBへ展開する。

## 2. 回路の役割分担

**AG256 CPLD** は5V→3.3V変換後のSFCアドレス・制御信号を受け、ROM4形式・SRAM2形式のアドレス変換、MEM A0–A4/A13–A22の生成、NOR/SRAM /CE・/OE・/WEの一元駆動、8T245のDIR/OEとLVC245A #1の/OE、SPECIAL_SELを担当する。通常ROM読出しにARM/UDBを経由させない。AG256はmicroSD信号を中継しない。

**PSoC 5LP** はARM演算、ゲームローダ、NOR書込み、BIOS、USB、microSD SPI、$5000 UDB通信とFIFO、DMA、IRQ、メモリ所有権FSM、SFC /RESET、DVDACを担当する。MEM制御GPIO4本はAG256の入力に接続し、メモリの制御ネットを直接駆動しない。SFCデータはP0[7:0]、MEMデータはP5[7:0]の独立ポートとする。

**8T245 ×1** はSFC D0–D7↔MEM D0–D7のみを双方向変換する。**74LVC245A ×5** は5V入力→3.3V出力に固定し、#1はSFC A5–A12→MEM、#2–#4はAG256のアドレス・制御入力、#5はBOOT_MODE等とmicroSD向け3出力を担当する。詳しい全38レーンの割り当ては[cpld.md](cpld.md)に記載する。

## 3. バス接続の概念

```text
SFC 5V A0..A23, /ROMSEL, /RD, /WR
       |           +----- [74LVC245A #2–#4 5V→3.3V] ----+
       |                                                  v
       +-- A5..A12 -- [74LVC245A #1 /OE] --> MEM A5..A12   AG256
       |                                              256 LUT
SFC D0..7 <------ [8T245 3.3V↔5V] -----> MEM D0..7        |
   |                     ^                                 +-- MEM A0..4/A13..22
PSoC P0 (5V)        AGM DIR/OE                              +-- NOR/SRAM /CE /OE /WE
                                                             +-- SPECIAL_SEL
PSoC MEM A0..22, P5 D0..7 ----------------------------------+-- shared 3.3V MEM
PSoC MEM 4 control outputs (3.3V) -------------------------> AG256 inputs
PSoC mode/BOOT (5V) ---- [74LVC245A #4–#5] --------------> AG256 inputs
PSoC SD SCK/MOSI/CS (5V) -- [74LVC245A #5] ---------------> microSD 3.3V
```

| MEM信号 | SFC所有時 | ARM所有時 |
|---|---|---|
| A0–A4 | AG256 | PSoC P2[0:4] |
| A5–A12 | 74LVC245A #1 | PSoC P2[5:7] / P6[0:4] |
| A13–A22 | AG256 | PSoC P6[5:7] / P1[2:7] / P15[4] |
| D0–D7 | 8T245経由でSFC、P0は通信専用 | PSoC P5[0:7] |
| /CE_ROM・/CE_RAM・/OE・/WE | AG256のSFCデコード | AG256がPSoCの4制御入力を選択 |

MEM制御ネットはAG256専用出力のためPSoC側との出力競合は発生しない。MEMアドレス23本とMEM D8本には引き続き競合防止のためHigh-Zハンドシェイクが必要である。ARM所有時もSPECIAL_SELとP0の通信は利用できる。

## 4. PSoC 100ピン割り当て

| ポート | 採用割当て（bit0から順） |
|---|---|
| P0 | SFC D0–D7（5V、通信・ブート直接応答） |
| P1 | SWDIO、SWDCK、MEM A16–A21（3.3V） |
| P2 | MEM A0–A7（3.3V） |
| P3 | CFG0–CFG3、MODE_HILO、SPECIAL_SEL、SFC /RD、/WR（5V） |
| P4 | SFC A0–A4、DVDAC、SFC A15、AG256 MEM_BUS_OE（5V） |
| P5 | MEM D0–D7（3.3V） |
| P6 | MEM A8–A15（3.3V） |
| P12 | SD SCK、MOSI、/CS、USB VBUS、AG256入力MEM /WE、SD MISO、AG256入力MEM /CE_ROM・/CE_RAM |
| P15 | SFC /ROMSEL、/RESET、/IRQ、**BOOT_MODE（P15[3]）**、MEM A22、AG256入力MEM /OE、USB D+、D− |

P15[3]の旧アドレス変換/OE用途は廃止し、BOOT_MODE専用出力に変更する。アドレス変換/OEはAG256が直接制御する。VDDIO0/3=5V、VDDIO1/2=3.3V、VDDA/VDDD=5Vとする。P0の8bitはSFC 5Vに直接接続し、P5の8bitは外部3.3V MEMデータとする。

PSoC I/Oは**72/72本**、AG256のI/O論理予算は**54/80本（入力31・出力23）**、LVC245Aのデータレーンは38/40本である。AG256のJTAG専用4本はI/O予算に含めない。物理ピン指定と専用機能ルーティングはPSoC Creator/AGM Supraで検証する。[pinout.csv](pinout.csv)をPSoC100ピンの正本とする。

## 5. 起動時の安全性

AG256が未初期化・JTAG書込み中のときもメモリの/CE・/OE・/WEをプルアップで非選択に維持する。LVC245A #1の/OE、8T245の/OEは3.3VプルアップでHigh-Zにし、PSoC MEM出力は初期化時に入力状態へ設定する。AG256のメモリ制御出力はSFC/ARM所有の切替中も非選択状態へ明示駆動し、制御出力そのもののHigh-Z切替は行わない。

AG256のMEMアドレス15本は所有権によりHigh-Zを切り替える。SPECIAL_SELはこれとは独立して有効にする。LVC245A #2–#5は常時方向固定だが、電源立上り時の入力未定義、Ioff、制御ピン初期値を確認する。

PSoCの/RESETはP15[1]で監視とオープンドレインLow保持・High-Z解除を行い、/IRQはP15[2]のオープンドレイン出力とする。SWDIO=P1[0]（20番）、SWDCK=P1[1]（21番）、XRES=15番、DVDAC=P4[5]（83番）を維持する。

## 6. PCB・試作と検証

FR-4、4層、厚さ1.2mm、SFCカートリッジ互換エッジ端子、試作ENIG。手はんだ可能なPSoC/AGM LQFP・TQFP-100、NOR TSOP-56、SRAM SOIC-32、8T245 SSOP-24、LVC245A TSSOP-20、PIC SOIC-8、LDO SOT-223を使用する。microSDはMEM2075-00-140-01-A、USBは1.2mm板厚対応Mini-Bを選定する。

AG256 JTAG、PSoC SWD、PIC ICSP、MEM /CE・/OE・/WE、AG256 OE、LVC245A #1 /OE、8T245 DIR/OE、SFCバスを測定できるパッドを確保する。AG256 256 LUT/80 I/Oのフィッティング、PSoC Creator、70ns NOR + 入力LVC245A + AG256 + 8T245の120ns FastROM STA、SFC電圧条件、NOR/SRAM排他、SRAMバックアップ、USB・追加音声を検証する。
