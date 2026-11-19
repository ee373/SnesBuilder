# CPLD・8bitレベル変換・高速バス仕様

Rev.0.8 / 2026-11-19更新。採用ハードウェアは **AGM AG256SL100 + SN74LVC8T245DBR ×1 + Nexperia 74LVC245APW,118 ×5**。本書は現行回路の接続契約を定義する。AGM Supraフィッタでの配置・実使用LUT・タイミング、および電気的実測は未完了。

## 1. 採用部品

| 用途 | 型番・条件 |
|---|---|
| CPLD | AGM Microelectronics **AG256SL100**、不揮発、256 LUT/LE、最大80ユーザーI/O、LQFP-100 |
| SFCデータ双方向変換 | TI **SN74LVC8T245DBR** ×1、8bit、VCCA=3.3V（MEM）、VCCB=5V（SFC）、SSOP-24 |
| アドレス・制御の5V→3.3V変換 | Nexperia **74LVC245APW,118** ×5、各8bit、VCC=3.3V、5V許容入力、TSSOP-20 |
| 外部メモリ | S29GL064S70TFI023（8MiB、70ns、x8）/ CY62128EV30LL-45SXI（128KiB、45ns） |

AG256のVDDC・VDDIO1/2・VDDF33はメーカーのRev1.2推奨動作条件に従い3.3Vを供給する。AG256には5Vを直接接続しない。74LVC245Aは3.3V電源の**片方向運用**とし、5V側が入力、3.3V側が出力である。双方向の5V電圧変換は8T245だけが担当する。

## 2. 6個の電圧変換ICの固定配分

各74LVC245AはDIR固定で5V入力→3.3V出力とする。入力/出力のA/B端子は配線時にDIR真理値表と照合する。入力を混在させても同じ方向であり、全出力は3.3Vである。

| 部品 | 8bitレーンの用途 | 出力先と出力許可 |
|---|---|---|
| 8T245 ×1 | SFC D0–D7 ↔ MEM D0–D7 | AGMがDIRと/OEを制御 |
| LVC245A #1 | SFC A5–A12 | MEM A5–A12、AGMが/OEを制御 |
| LVC245A #2 | SFC A0–A4、A13–A15 | AG256入力、常時有効（安全電源条件に従う） |
| LVC245A #3 | SFC A16–A23 | AG256入力、常時有効 |
| LVC245A #4 | SFC /ROMSEL・/RD・/WR、**SFC A12の複製**、PSoC CFG0–CFG3 | AG256入力、常時有効 |
| LVC245A #5 | PSoC MODE_HILO、MEM_BUS_OE、**BOOT_MODE**、SD_SCK、SD_MOSI、SD_/CS | 最初の3本はAG256入力、SDの3本はmicroSDに直接接続。2レーン未使用 |

変換対象はLVC245A側で8+8+8+8+6=**38/40レーン**。#1のA5–A12はMEM所有権切替時にHigh-Zとなるため、SFC A12を#4でもう一度受けてAG256の特殊領域デコードを維持する。microSDのSCK/MOSI//CSはAG256を経由せず#5から直接供給し、MISOはPSoCの3.3V SIO P12[5]へ直結する。#5の/OEとDIRはAG256から独立した固定方向・安全初期値とする。

8T245はA側がMEM 3.3V、B側がSFC 5V。**DIR=High: A→B（MEM→SFC）、DIR=Low: B→A（SFC→MEM）、/OE=High: High-Z**。DIRと/OEの制御電圧はVCCA側の3.3Vである。/OEには3.3Vプルアップ、DIRにはデフォルトを定義する抵抗を設ける。

LVC245A #1はARM所有時、電源投入中、隔離中に/OE=Highとする。#2–#5はメモリバスを駆動しないため、SFC側アドレスやPSoC設定信号の監視を継続できる。#2–#5の初期出力許可はSFC/PSoC双方の起動状態と入力未定義時の扱いを回路図で確認する。

## 3. MEMアドレスと共有メモリの接続

| 共通MEMアドレス | SFC所有時 | ARM所有時 |
|---|---|---|
| A0–A4 | AG256（SFC A0–A4を出力） | PSoC P2[0:4] |
| A5–A12 | LVC245A #1（SFC A5–A12を出力） | PSoC P2[5:7] / P6[0:4] |
| A13–A14 | AG256（SFC A13–A14を出力） | PSoC P6[5:6] |
| A15–A22 | AG256（ROM/SRAM形式で変換） | PSoC P6[7] / P1[2:7] / P15[4] |

PSoCはMEM A0–A22の23本を維持する。SFC所有時はPSoCの23本をすべてHigh-Zにし、ARM所有時はAG256のメモリアドレス出力15本とLVC245A #1の8本をHigh-Zにする。SRAMの物理配線はSRAM A0–A12=MEM A0–A12、SRAM A13–A16=MEM A16–A19に固定する。

ROMのHiROM/LoROM/Ex形式に対応するA15–A22の変換と、HiROM SRAM 8KiB窓/LoROM SRAM 32KiB窓のMEM A16–A19生成はAG256で行う。容量ミラーリングはゲームローダがNORへの事前展開で行う。

## 4. メモリ制御信号のAG256一元化

**NOR /CE、SRAM /CE、共通/OE・/WEはAG256だけがメモリ側を駆動する。** 従来のようにPSoCとCPLDの出力を同一制御ネットに直結しない。

PSoCのMEM_/CE_ROM=P12[6]、MEM_/CE_RAM=P12[7]、MEM_/OE=P15[5]、MEM_/WE=P12[4]は、3.3V側からAG256の**入力**へ直結する。AG256は所有権に応じてSFC側デコード/ストローブまたはPSoC側4入力を選択する。隔離中と初期化前はROM/SRAM非選択、/OE=/WE非アクティブに固定する。AG256の4出力には独立した3.3Vプルアップを設け、起動中・CPLD未構成中・JTAG書込み時にも非選択を保証する。

SFC→ARM切替はWRAM実行、外部ストローブ停止、AG256アドレスOE無効化、LVC245A #1無効化、8T245無効化、ガード時間、PSoC MEM GPIO出力有効化の順序とする。返却時は逆順で、AG256はメモリ制御線を常時安全状態に駆動する。制御出力をHigh-Zにする方式は採用しない。

| SFCアクセス種別 | 8T245 | ROM /CE | RAM /CE | /OE | /WE |
|---|---|---|---|---|---|
| NOR読み出し | A→B | 有効 | 無効 | 有効 | 無効 |
| SRAM読み出し | A→B | 無効 | 有効 | 有効 | 無効 |
| SRAM書き込み | B→A | 無効 | 有効 | 無効 | 有効 |
| $5000・固定ブート | High-Z | 無効 | 無効 | 無効 | 無効 |
| ARM MEM所有 | High-Z | PSoC入力による | PSoC入力による | PSoC入力による | PSoC入力による |
| 隔離・起動 | High-Z | 無効 | 無効 | 無効 | 無効 |

SRAM書込み時は8T245の方向とデータが確定してから/WEを有効にし、書込み終了後のデータ保持時間を保証する。NORの消去・書込みはARM所有中に限定する。

## 5. SPECIAL_SELとBOOT_MODE

AG256はSFCのA0–A4、A12–A23、/ROMSEL・/RD・/WR、およびPSoCのCFG[3:0]、MODE_HILO、MEM_BUS_OE、BOOT_MODEを受ける。SFC A5–A11をAG256へ入力する必要はない（MEMにのみ接続する）。通信・ブート候補デコードは以下のとおり。

- 通信: システムバンク$00–$3F/$80–$BFの$5000–$5FFFを選択、設定で拡張有効化。AG256がSPECIAL_SELを出力し、PSoC P3[5]がSFC A15とA0–A4でレジスタを確定する。
- BOOT_MODE: PSoC P15[3]を専用**BOOT_MODE出力**へ変更し、LVC245A #5からAG256へ入力する。BOOT_MODE中の$00:8xxx/$00:Fxxxをブート候補として選択する。実データ応答はPSoCが$00:8000–8003/$00:FFFC–FFFDの6バイトだけを返す。
- ブート候補および$5000ではNOR/SRAMの/CEを無効化し、8T245をHigh-Zとする。PSoC SFC P0[7:0]が直接応答する。
- ARMがMEMを所有していてもSPECIAL_SELは有効とし、$5000通信を継続する。BOOT_MODE中でも$2F:6000–$2F:7FFFのSRAM BIOS窓は有効にする。
- CFG0–CFG3とMODE_HILOの**機能コード表**はAG256 RTL作成時に一意に定義する。BOOT_MODEはCFGから独立した専用線とする。

## 6. AG256SL100 論理I/O予算

| AG256入力 | 本数 |
|---|---:|
| SFC A0–A4、A12–A23（5V→3.3V済み） | 17 |
| SFC /ROMSEL・/RD・/WR（変換済み） | 3 |
| PSoC CFG0–3、MODE_HILO、MEM_BUS_OE、BOOT_MODE（変換済み） | 7 |
| PSoC MEM /CE_ROM、/CE_RAM、/OE、/WE（3.3V直結） | 4 |
| **入力合計** | **31** |

| AG256出力 | 本数 |
|---|---:|
| MEM A0–A4、A13–A22 | 15 |
| NOR/SRAM /CE、MEM /OE・/WE | 4 |
| 8T245 DIR・/OE | 2 |
| LVC245A #1 アドレス/OE | 1 |
| SPECIAL_SEL | 1 |
| **出力合計** | **23** |

**計54/80 I/O（入力31＋出力23、余剰26本）**。JTAG TMS/TDI/TCK/TDOは別の専用端子を使用する。AG256は256 LUTで、実LUT使用量・ピン配置・タイミングはSupraによる合成・フィッティングで確定する。旧LC4064V固有の「専用入力」「GOE」「64マクロセル」という資源計数は適用しない。

## 7. 電源・タイミング・設計検証

AG256の全VDDC、VDDIO1/2、VDDF33に3.3Vを供給し、電源端子ごとにデカップリングを配置する。PSoCの5V GPIO信号はLVC245Aで変換し、PSoCの3.3V MEM制御4本だけをAG256に直結する。AG256出力3.3VのSPECIAL_SELをPSoCの5Vドメインで受ける際はLVTTL設定・VIHを確認する。PSoCの/RESETとSFC D0–D7は従来どおり5V直接接続を維持する。

FastROM目標120ns、SlowROM200ns。最長経路はSFC A→LVC245A→AG256→NOR（70ns）→8T245→SFC Dおよび/ROMSEL→LVC245A→AG256→NOR /CE→8T245→SFC D。SRAM書込みのデータ/WE競合、LVC245A #1のHigh-Z切替、8T245のDIR/OE、SFC 5V VIH/VOHも測定対象とする。

AGM Supraにて256 LUT・54 I/Oへの収容、AG256 LQFP100物理ピン割当て、全デコード論理、出力High-Z、STAを検証する。資料上のLUT数やメーカー公称素子遅延だけを合格判定としない。AGM Supraのライセンス取得条件・書込み治具・JTAG動作も試作前に確定する。

参考: [AGM AG256製品](https://www.agmcn.com/product-news/1667.html)、[AGM CPLD Rev1.2](https://www.agm-micro.com/upload/userfiles/files/AG_CPLD_Rev1_2.pdf)、[TI 8T245](https://www.ti.com/product/SN74LVC8T245)、[Nexperia LVC245A](https://www.nexperia.com/products/analog-logic-ics/logic/buffers-inverters-transceivers/transceivers/serie/74lvc245a-74lvch245a)。
