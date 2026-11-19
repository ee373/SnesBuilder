# ハードウェア基本仕様

Rev.0.8 / 2026-11-19。採用回路の接続方針を記載する。CPLD/Creatorの物理ピン制約、STAおよび電気的検証は未完了である。

## 1. 基本構成

| 項目 | 採用仕様 |
|---|---|
| 対応機種 | スーパーファミコン / SNES |
| メインMCU | Infineon PSoC 5LP CY8C5287AXI-LP095、ARM Cortex-M3 最大80MHz |
| MCU内蔵メモリ | Flash 256KiB / SRAM 64KiB / EEPROM 2KiB |
| PSoC UDB | 24 UDB、48 PLD、192マクロセル、24データパス |
| CPLD | Lattice LC4064V-75TN100C、3.3V、64マクロセル、64 I/O＋10専用入力、100-TQFP |
| 双方向レベル変換 | SN74LVC16T245DLR、3.3V側A / 5V側B、8bit独立2グループ |
| 外部ROM | S29GL064S70TFI023、8MiB、x8、70ns、3.3V |
| 外部RAM | CY62128EV30LL-45SXI、128KiB、45ns、3.3V、電池バックアップ |
| ROM形式 | HiROM、ExHiROM、LoROM、ExLoROM |
| ROMミラー | ゲームロード時のNORイメージ事前展開 |
| ROMアクセス目標 | SlowROM 200ns以内、FastROM 120ns以内（合成・実機検証待ち） |
| SFCインターフェース | 5V、24bitアドレス、8bitデータ |
| 共通メモリバス | 3.3V、23bitバイトアドレス、8bitデータ |
| 外部メモリ所有 | SFCとPSoC ARMで排他切替 |
| CPU間通信 | $5000–$5FFFの32アドレス＋双方向4byte FIFO＋DMA・IRQ |
| 記録媒体 | microSD（SPI） |
| PC通信 | USB Full-Speed、12Mbps、PSoCはUSBデバイス |
| 追加音声 | PSoC DVDAC→LPF→MCP6001→SFCカートリッジ外部音声L/R |
| CIC | PIC12F629、SuperCIC Keyを使用する想定 |
| 開発・量産実装 | 4層1.2mm基板、ENIG端子、外部リード付きIC、試作は手はんだ |

NORの全8MiBをゲームイメージとリソースに使用できる構成とし、SFC側BIOSはPSoC内蔵Flashに保存して起動時に共有SRAM末尾8KiBへ展開する。

## 2. 回路の役割分担

**CPLD** は5VのSFCアドレス・制御を入力し、3.3VのROM/SRAMアドレス・/CE・/OE・/WEを高速生成する。HiROM/LoROM系のアドレス変換、SRAMウィンドウの選択、バス所有権に応じたHigh-Z制御、16T245第1グループのDIR・/OE、SPECIAL_SEL、microSD向け3信号の5V→3.3V変換を担当する。通常のROM読出しにARMやUDBを経由させない。

**PSoC 5LP** はARM演算、ゲームローダ、NOR消去・書込み、BIOS展開、USB、microSDアクセス、$5000通信レジスタ、FIFO、DMA、IRQ、バス所有権のハンドシェイク、SFCリセット、および追加音声を担当する。SFCデータバスP0と共有MEMデータバスP5は独立した8bitポートとする。

**SN74LVC16T245DLR** はグループ1（データ8bit双方向）とグループ2（アドレス8bit SFC→MEM）に分ける。VCCA=3.3V、VCCB=5Vとする。DIR/OE制御入力はVCCA基準の3.3V系で駆動する。グループ2の/OEは所有権を制御するPSoC P15[3]からオープンドレインと3.3Vプルアップを介して駆動し、グループ1のDIR/OEはCPLDが生成する。各制御信号の非アクティブ初期値を抵抗で保証する。

詳細の論理的I/O配分は[cpld.md](cpld.md)、電源は[power-cic.md](power-cic.md)を正本とする。

## 3. SFC／メモリバス接続

```text
      SFC 5V A0..A23, /ROMSEL, /RD, /WR
                   |            |
                   |            +---------------------+
                   v                                  v
        +-------------------+                 +------------------+
        | LC4064V CPLD 3.3V |                 | PSoC SFC inputs  |
        | mapper /CE/OE/WE  |                 | P4 A0..4, A15    |
        | MEM A0..4,13..22  |                 | P0 SFC D0..7     |
        +---------+---------+                 +---------+--------+
                  |                                     |
                  +---- shared MEM A0..22               |
                  |                                     |
SFC A5..12 -------+---- [16T245 group 2 B->A] -- MEM A5..12
SFC D0..7 <------------ [16T245 group 1] <----> MEM D0..7
                  |                                     |
                  +---- 8MiB NOR / 128KiB SRAM         |
                                ^                       |
                                +---- PSoC MEM A/D/control
```

| MEM信号 | SFC所有時の駆動 | ARM所有時の駆動 |
|---|---|---|
| A0–A4 | CPLD SFC A0–A4 | PSoC P2[0:4] |
| A5–A7 | 16T245 SFC A5–A7 | PSoC P2[5:7] |
| A8–A12 | 16T245 SFC A8–A12 | PSoC P6[0:4] |
| A13–A14 | CPLD SFC A13–A14 | PSoC P6[5:6] |
| A15 | CPLD（ROM/形式に応じる） | PSoC P6[7] |
| A16–A21 | CPLD（ROM/SRAM形式に応じる） | PSoC P1[2:7] |
| A22 | CPLD | PSoC P15[4] |
| D0–D7 | SFC⇄MEMは16T245、通信時はPSoC P0直結 | PSoC P5[0:7] |
| /CE_ROM・/CE_RAM・/OE・/WE | CPLD | PSoC P12・P15 |

SFC所有時、PSoCのMEMアドレス出力はすべてHigh-Zとする。ARM所有時、CPLDのメモリアドレス15出力と16T245アドレス側8出力はHigh-Zとする。通信領域では16T245のデータ側をHigh-Zにし、PSoC P0からSFCへ直接応答する。

## 4. PSoC 100ピン割り当て

| ポート | 採用する割り当て（bit0から順） |
|---|---|
| P0 | SFC D0–D7（5V） |
| P1 | SWDIO、SWDCK、MEM A16–A21（3.3V） |
| P2 | MEM A0–A7（3.3V） |
| P3 | CPLD CFG0–CFG3、MODE_HILO、SPECIAL_SEL、SFC /RD、SFC /WR（5V） |
| P4 | SFC A0–A4、DVDAC P4[5]、SFC A15、CPLD MEM_BUS_OE（5V） |
| P5 | MEM D0–D7（3.3V） |
| P6 | MEM A8–A15（3.3V） |
| P12 | SD SCK、MOSI、/CS、USB VBUS検出、MEM /WE、SD MISO、MEM /CE_ROM、MEM /CE_RAM |
| P15 | SFC /ROMSEL、/RESET、/IRQ、16T245アドレス側/OE、MEM A22、MEM /OE、USB D+、D− |

VDDIO0/3は5V、VDDIO1/2は3.3V、VDDA/VDDDは5Vとする。CPLDから5VドメインのPSoCへ接続するSPECIAL_SELなどの3.3V出力はLVTTL入力しきい値へ設定し、実機条件を確認する。P0の8bitは5VのSFCデータ専用、P5の8bitは3.3Vの外部MEMデータ専用とする。

| 資源 | 占有 |
|---|---:|
| PSoC I/O（SIO/USBIOを含む） | 72/72 |
| CPLD汎用I/O | 50/64 |
| CPLD専用入力（CFG） | 4/10 |

CPLD入出力50本の内訳、専用入力端子の条件、SPECIAL_SELとバスOEは[cpld.md](cpld.md)を参照する。PSoCの全物理ピンは[pinout.csv](pinout.csv)に列挙する。物理ピン・GPIO/DSI配線はPSoC CreatorおよびLatticeフィッタで検証する。

## 5. 安全な出力状態

電源投入、PSoC起動前、SFCリセット保持中の回路設定、バス所有権切替中は、外部メモリの/CE・/OE・/WEを非アクティブとし、CPLD/16T245/PSoCの出力競合を防止する。

PSoC P15[3]は3.3Vプルアップ付きのオープンドレインとして16T245のアドレス側/OEを駆動する。CPLD MEM_BUS_OEの非アクティブ初期値とメモリの制御信号には独立したプル抵抗を備える。CPLDのメモリ出力がHigh-ZでもSPECIAL_SELとmicroSD出力が維持されるよう、出力グループごとにOE条件を分離する。

SFCの/RESETはP15[1]で入力監視とオープンドレインLow駆動/High-Z解除を行う構成とし、本体回路・CICとの電気的な整合を検証する。/IRQはP15[2]のオープンドレイン出力とする。PSoC SWDIO=P1[0]（20番）、SWDCK=P1[1]（21番）、専用XRES=15番、DVDAC=P4[5]（83番）、SFC /IRQ=P15[2]（55番）を維持する。

## 6. PCB、接続端子、試作

FR-4、4層、板厚1.2mm、SFCカートリッジ互換エッジ端子を採用し、試作端子はENIGとする。金端子寸法、接触面取り、耐摩耗は実物と製造仕様で確定する。初期試作は手はんだとし、PSoC/CPLD TQFP-100、NOR TSOP-56、SRAM SOIC-32、16T245 SSOP-48、PIC SOIC-8、LDO SOT-223、音声オペアンプ SOT-23を使用する。

microSDスロットはMEM2075-00-140-01-A、USBは1.2mm基板に適合する信号端子を含むスルーホールMini-Bを採用する。カード検出用GPIOは用意せずSPI初期化で有無を判定する。SWD、CPLD JTAG、PIC ICSP、電源レール、MEM /CE・/OE・/WE、OE、およびSFCバス制御を測定できるテストパッドを確保する。

## 7. 次の検証

CPLDの論理合成で64マクロセル、50汎用I/Oへの収容と端子OEの実現性を確認する。特にROM/CE・/OE・データ返却を含む120ns FastROM、SRAM書込みタイミング、MEMとSFC Dの電気的競合、SFC信号の3.5V HIGH条件、microSD 5V/3.3V変換、PSoC CreatorのDVDAC・FIFO・DSI制約を検証する。
