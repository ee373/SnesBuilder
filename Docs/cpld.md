# CPLD・レベル変換・高速バス仕様

Rev.0.8 / 2026-11-19。設計上の接続契約と論理要求を定める。物理ピン番号、マクロセル使用量、タイミング適合は論理合成と回路図で確定する。

## 1. 採用部品と電源

- CPLD: Lattice **LC4064V-75TN100C**（ispMACH 4000V、3.3V、64マクロセル、100-TQFP、64汎用I/O＋10専用入力、7.5ns速度グレード、5V許容入力）。
- データ／アドレス用電圧変換: TI **SN74LVC16T245DLR**（48-SSOP、16bit、2組の8bitでDIRと/OE独立）。**VCCA=3.3V（MEM側）、VCCB=5V（SFC側）**。DIRおよび/OE入力はVCCA基準の3.3V論理で駆動する。
- 外部メモリ: S29GL064S70TFI023（8MiB、70ns、x8）とCY62128EV30LL-45SXI（128KiB、45ns）。

CPLDはSFCの5Vアドレス・制御信号を受ける。CPLD出力は3.3VでMEMバスとPSoC側へ接続する。16T245のBポートは5V、Aポートは3.3Vとし、OE無効時は双方向ともHigh-Zとする。SFC信号の5V HIGHレベルに対する16T245のB側VIH（5Vで約3.5V）と実機のVOHは実測で照合する。SFC側5V端子をCPLDの5V許容入力以外の3.3V専用入力へ直接接続しない。

## 2. アドレス接続

| 共通メモリバス | SFC所有時の駆動源 | ARM所有時 |
|---|---|---|
| MEM A0–A4 | CPLD（SFC A0–A4） | PSoC GPIO |
| MEM A5–A12 | 16T245第2グループ（SFC A5–A12） | PSoC GPIO |
| MEM A13–A14 | CPLD（SFC A13–A14） | PSoC GPIO |
| MEM A15–A22 | CPLD（ROM/SRAM形式で変換） | PSoC GPIO |

PSoCにはMEM A0–A22の23本を従来どおり全接続する。SFC所有時のPSoC MEMアドレス出力はすべてHigh-Zにする。CPLDのA0–A4/A13–A14/A15–A22計15本と16T245アドレス側8本を隔離することでARMの全23bitを使用可能にする。

SRAM A0–A12はMEM A0–A12、SRAM A13–A16はそれぞれMEM A16–A19へ接続する。SRAM選択中もこの物理接続は固定であり、CPLDがMEM A16–A19の出力値をSRAM窓に合わせて変換する。

## 3. データ接続

- **SFC D0–D7** はPSoC P0[0:7]へ5Vで直結し、同じ配線を16T245第1グループB側へ接続する。
- **MEM D0–D7** はNOR/SRAM/PSoC P5[0:7]と16T245第1グループA側に接続する。
- 通常のROM/SRAM読出しはMEM→SFC、SRAM書込みはSFC→MEM、通信・ブート応答とARM所有時は第1グループ/OEを無効にする。
- 16T245第2グループはSFC A5–A12→MEM A5–A12専用。DIR=Low（B→A）、/OEはバス所有権に従ってHigh-Z切替する。
- 第1グループはDIR=LowがMEM→SFC、DIR=HighがSFC→MEM（TIデータシートのA→B規定）。DIR変更時は/OEをHighにして両側を隔離する。

PSoC P0をSFC通信用に維持するため、ARMがMEM DバスでNOR/SRAMアクセス中でも$5000通信は独立して行える。

## 4. CPLD信号数（論理I/O割当予算）

| 用途 | 入力 | 出力 |
|---|---:|---:|
| SFC A0–A4 | 5 | 0 |
| SFC A12–A23 | 12 | 0 |
| SFC /ROMSEL・/RD・/WR | 3 | 0 |
| HiROM/LoROM選択 | 1 | 0 |
| PSoCバス出力許可 | 1 | 0 |
| MEM A0–A4 | 0 | 5 |
| MEM A13–A14 | 0 | 2 |
| MEM A15–A22 | 0 | 8 |
| NOR /CE・SRAM /CE | 0 | 2 |
| MEM /OE・/WE | 0 | 2 |
| 16T245第1グループDIR・/OE | 0 | 2 |
| SPECIAL_SEL（PSoC入力） | 0 | 1 |
| PSoC SD_SCK・SD_MOSI・SD_/CS → microSD | 3 | 3 |
| **汎用I/O合計** | **25** | **25** |

汎用I/Oは**50/64本、残り14本**とする。さらに専用入力4本をPSoC CFG[3:0]に割り当てる（残り6本）。JTAGは書込み・検査に使用する。PSoCのバスOE用入力には専用GOE機能を利用する方針とするが、SPECIAL_SELやmicroSD出力はメモリ出力のHigh-Z化に連動させず、**出力ごとにOEを割り当てる**。50本は信号の論理的な必要数であり、個々のパッケージ端子への配置と製品ごとの5V許容制約はCPLDフィッタで確定する。

## 5. 選択・デコード仕様

ゲーム起動前に設定するCPLDモードには、HiROM系/LoROM系、拡張4MiB領域の有無、BOOT_MODE、通信拡張有効化、SFC/ARMのバス所有権、および隔離状態を含める。**MODE_HILOとCFG[3:0]のコード表はHDL設計時に一意に定義する。** ROMの容量ミラーはゲームローダによるNORへの事前配置で処理する。

- ROM読出しではアドレス形式に応じてMEM A15–A22を生成する。
- SRAM選択時にはHiROM/LoROMそれぞれの窓をデコードし、SRAM A13–A16に相当するMEM A16–A19を生成する。
- ROM、SRAM、通信、ブート固定値を排他的に選択し、ブート固定値/通信ではメモリ/CEと16T245データ側/OEを無効にする。
- /ROMSELだけに依存してSRAMを選択しない。LoROMのSRAM窓や通信領域をSFCアドレスから独立にデコードする。
- SPECIAL_SELは、システムバンクの$5000–$5FFF、またはBOOT_MODE中の$00:8xxx/$00:Fxxxへのアクセス候補を表す。PSoC側は**SFC A15**で通信（A15=0）とブート候補（A15=1）を分離し、A0–A4とメモリアドレス入力の下位ビットで最終的な6バイト固定応答を判定する。
- ブート期間の$00:8xxx/$00:Fxxxでは対象ウィンドウのNORを非選択にし、実際にPSoCが応答するのは$00:8000–8003と$00:FFFC–FFFDの6アドレスに限定する。SFCが他のブートウィンドウを読まないことをBIOS/起動シーケンスで保証する。
- ARM所有中もSPECIAL_SELの$5000検出を継続し、SFC Dを通じてPSoCが応答する。

## 6. バス切替とHigh-Z契約

切替はSFCがWRAM実行に移行しカートリッジアクセスを止めた後に実施する。PSoCはCPLDのメモリアドレス・制御出力、16T245の両グループを無効化し、NOR/SRAMの/CE・/OE・/WEを非アクティブにしてからGPIOのドライブモードを変更する。

SFC所有に戻すときは、PSoCのMEM端子をHigh-Zにし、制御信号が非アクティブであることを確認してからCPLD/16T245を有効にする。全制御信号は電源投入中・隔離中・PSoC未初期化中に安全な非選択状態を維持するプル抵抗を設ける。OEをHigh-Zにするだけではプルアップを省略しない。

microSD用3信号はCPLDの**5V入力→3.3V出力**を使用する。PSoC側の既存P12信号を保持し、microSD側/CSはプルアップ、SCKはプルダウンを基本とする。microSDのMISOはPSoCの3.3V SIOへ直接接続する。

## 7. タイミング検証

FastROM目標は120ns以内、SlowROMは200ns以内とする。S29GL064Sはアドレス・/CE起点最大70ns、/OE起点最大15ns、CY62128は45nsである。CPLDの「7.5ns」は規定条件付きの製品速度グレードであり、全経路の実遅延ではない。

実際に評価する最大経路は、(1) SFC A→CPLD→MEM A→NOR→16T245→SFC D、(2) SFC /ROMSEL→CPLD→NOR /CE→データ、(3) SFC /RD→CPLD→/OE・16T245出力有効化→SFC D、(4) SRAM書込み時の/WEとデータセットアップである。合成後のピン間遅延、基板の容量負荷、NOR/SRAM規定を重ねてSTAを行う。試算約112nsは機能実証値ではない。

## 8. 検証成果物

Latticeツールで4形式のデコードとSRAM窓、SPECIAL_SEL、OE/所有権遷移、microSD信号の論理収容（64マクロセル、50汎用I/O）を確認する。PSoC CreatorではP0/P5、CFG、SPECIAL_SEL、DMA/FIFO、アナログ出力の端子制約を確認する。論理テストベンチではROM/SRAM排他、ブート6バイト、ARM所有中の通信、NOR書込み隔離、電源投入時安全状態を検証する。

参考: [Lattice ispMACH 4000V](https://www.latticesemi.com/Products/FPGAandCPLD/ispMACH4000VZ)、[TI SN74LVC16T245](https://www.ti.com/product/SN74LVC16T245)。
