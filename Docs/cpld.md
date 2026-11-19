# CPLD・レベル変換・高速バスの接続仕様

Rev0.8 改訂案 / 2026-11-19。SFCの端子配列から部品配置を組み直した設計仕様。物理ピン候補とI/O数を確定し、AGM Supraでの合成・フィッティングとSTAは次工程とする。PSoCの端子表は[pinout.csv](pinout.csv)、AG256の全54信号は[cpld-pinout.csv](cpld-pinout.csv)を参照。

## 1. デバイスと電圧

| 部品 | 個数 | 役割 |
|---|---:|---|
| AGM AG256SL100 / LQFP100 / 3.3V | 1 | ROM4形式、7段階の容量ミラー、SRAM2形式、メモリ選択、バス所有権、SPECIAL_SEL |
| TI SN74LVC8T245DBR | 1 | SFC D0–D7（5V）↔MEM D0–D7（3.3V）の8bit双方向変換 |
| Nexperia 74LVC245APW,118 | 5 | 3.3V電源・5V許容入力の8bit片方向変換（全40レーン中38使用） |
| S29GL064S70TFI023 | 1 | 8MiB NOR Flash、x8・70ns |
| CY62128EV30LL-45SXI | 1 | 128KiB SRAM、45ns |

74LVC245Aはすべて5V信号を入力とし、3.3V信号を出力する固定方向とする。PSoCの3.3Vメモリ制御4線はAG256へ直結する。AG256自体へ5Vを印加しない。

## 2. レベル変換ICの物理的なレーン再配分

| IC | 8bitレーンの接続 | /OE |
|---|---|---|
| SN74LVC8T245 | SFC D0–D7 ↔ MEM D0–D7 | AG256がDIRおよび/OEを制御 |
| LVC245A #1 | **SFC A4–A11 → MEM A4–A11** | AG256がMEM所有権に応じて制御 |
| LVC245A #2 | SFC A0–A3、A12–A15 → AG256入力 | 通常のSFC監視中は有効 |
| LVC245A #3 | SFC A16–A23 → AG256入力 | 通常のSFC監視中は有効 |
| LVC245A #4 | SFC /ROMSEL、/RD、/WR、PSoC ARM_MEM_ENABLE、ROM_SIZE[0:2]、MODE_HILO → AG256入力 | 通常は有効 |
| LVC245A #5 | PSoC MEM_BUS_OE、EXTENSION_ENABLE、BOOT_MODE → AG256、PSoC SD_SCK・SD_MOSI・SD_/CS → microSD | 通常は有効、2レーン予備 |

#1はSFC端子6～13番のA11～A4という連続8信号を受ける。MEM A12はAG256が生成するため、以前のA12複製入力は不要になる。#2・#3はSFC上位アドレスを監視し続けるため、ARMがMEMバスを所有しているときもSPECIAL_SELを生成できる。

8T245はA側=MEM 3.3V、B側=SFC 5Vとし、DIR=HighでMEM→SFC、DIR=LowでSFC→MEM、/OE=HighでHigh-Z。/OEは3.3Vプルアップ、DIRは安全な初期値を抵抗で定義する。#1の/OEも3.3Vプルアップで起動時High-Zを保証する。

## 3. SFC/ARM共有MEMバス

| MEM信号 | SFC所有中 | ARM所有中 |
|---|---|---|
| A0–A3 | AG256出力 | PSoC P2[0:3] |
| A4–A11 | 74LVC245A #1出力 | PSoC P2[4:7]、P6[0:3] |
| A12–A15 | AG256出力 | PSoC P6[4:7] |
| A16–A21 | AG256出力 | PSoC P1[2:7] |
| A22 | AG256出力 | PSoC P12[6] |
| D0–D7 | 8T245経由でSFCへ接続 | PSoC P5[0:7] |
| /CE_ROM・/CE_RAM・/OE・/WE | AG256がSFC信号から生成 | AG256がPSoCのメモリ制御4入力を選択 |

SFC所有中はPSoCのMEMアドレス23本とMEMデータ8本をHigh-Z、ARM所有中はAG256のアドレス15出力、LVC245A #1、8T245をHigh-Zとする。AG256のメモリ制御4出力はHigh-Z化せず、隔離・起動中も非選択を駆動する。外付けのプルアップによりAG256未動作時も非選択を維持する。NORとSRAMの同時選択を禁止する。

SRAM物理A0–A12=MEM A0–A12、物理A13–A16=MEM A16–A19。SFC SRAMアクセス時にはROM容量マスクを無効にし、HiROM 8KiB窓またはLoROM 32KiB窓のアドレス変換を使用する。MEM A12はSFC A12を通過する。

## 4. ROMの形式と7段階容量マスク

| ROM_SIZE[2:0] | 実データ容量 | 容量マスク |
|---|---|---|
| 000 | 128KiB | ROM A17–A22 = 0 |
| 001 | 256KiB | ROM A18–A22 = 0 |
| 010 | 512KiB | ROM A19–A22 = 0 |
| 011 | 1MiB | ROM A20–A22 = 0 |
| 100 | 2MiB | ROM A21–A22 = 0 |
| 101 | 4MiB | ROM A22 = 0 |
| 110 | 8MiB | マスクなし（ExHiROM/ExLoROMの4MiB領域選択） |
| 111 | 予約 | 不正値としてROM非選択の安全状態を選択 |

HiROM/LoROMの物理アドレスを生成した後でマスクを適用する。例えば物理A17の許可信号はSIZE≧1、A18はSIZE≧2、…、A22はSIZE≧6となる。この比較とマッピングMUXは可能な限り同じLUTで実装する。8MiB時はMODE_HILOで選択したExHiROMまたはExLoROMの4MiB領域デコードを使用する。実データが3MiBならNOR上で4MiB、5～6MiBなら8MiBへ元ゲームのミラー規則で展開してから対応するROM_SIZEを設定する。

容量マスク専用の追加CPLDピンは不要であり、PSoC P4[1:3]の3本を#4経由で入力する。容量ミラーリングはNORのアドレスだけに適用し、SRAMやARMによるNOR書込みアドレスには適用しない。

## 5. 特殊応答・レジスタ・バス調停

AG256はSFC A0–A3、A12–A23、/ROMSEL・/RD・/WRと、PSoC側の8設定信号を入力する。SFC A4–A11はMEMへ向かうだけで、CPLDに入力しない。PSoC SFCバスへはSFC A0–A3（P3[0:3]）、SPECIAL_SEL（P3[4]）、/RD・/WR（P3[6:7]）、/ROMSEL（P15[0]）が直接到達する。

通信領域は$00–$3F/$80–$BF:$5000–$5FFF、16アドレスを窓内へミラーする。EXTENSION_ENABLEで通信を有効化し、選択されない場合は通常マップを維持する。BOOT_MODE中は$00:FFFC–FFFDおよび$00:8000–8003への応答をPSoCが行う。AG256のSPECIAL_SELは「ブート候補または通信候補」を示し、PSoC側が/ROMSELとA3–A0およびBOOT_MODEで応答を識別する。特殊応答中のNOR/SRAMは非選択、8T245はHigh-ZでPSoC P0[7:0]のみがSFCデータを駆動する。ブート応答の6バイト以外へのデータ駆動は禁止する。

所有権の制御はARM_MEM_ENABLEとMEM_BUS_OEを使用する。

| ARM_MEM_ENABLE | MEM_BUS_OE | 状態 |
|---:|---:|---|
| 0 | 0 | 隔離 |
| 0 | 1 | SFC所有 |
| 1 | 0 | ARM所有 |
| 1 | 1 | 異常時の隔離 |

隔離状態でAG256のアドレス出力と#1/8T245をHigh-Zとし、MEM /CE_ROM、/CE_RAM、/OE、/WEをすべて非アクティブにする。SFCは本体WRAM上のコードからバス切替を要求し、PSoCのARM＋UDB FSMがISO→QUIET→CONFIG→GUARD→OWNERの手順を完了させる。ARM所有中もSPECIAL_SELを継続する。

## 6. AG256物理ピンおよびI/O数

AG256の物理ピン指定はメーカーのAG256/AG272 100-pin pinout表を基にした[cpld-pinout.csv](cpld-pinout.csv)に記録する。SFC A0–A3を26～29、A12–A23を33～44、/ROMSEL・/RD・/WRを47～49、PSoCのモード設定を1～8および12/14～16、MEMアドレス出力を51～69の使用可能端子へ集約する。

| 種別 | 内訳 | 本数 |
|---|---|---:|
| 入力 | SFCアドレス16、SFCストローブ3、PSoC設定8、ARM MEM制御4 | 31 |
| 出力 | MEMアドレス15、MEM制御4、8T245 DIR/OE 2、#1 /OE 1、SPECIAL_SEL 1 | 23 |
| **合計** | | **54/80** |

JTAG 22～25番は専用に保持し、電源・GND/VDDF33の端子は信号へ使用しない。これらは物理的なピン候補であり、AGM Supraフィッティングとピンロックで配置可能性を確定する。

## 7. FastROMタイミング評価の基準

| 経路要素 | 暫定遅延 |
|---|---:|
| 74LVC245A 5V→3.3V | 6.3ns（採用品の条件付き最大値として再照合） |
| S29GL064S NOR（tACCまたはtCE） | 70ns |
| SN74LVC8T245 3.3V→5V | 4.4ns（採用品の条件付き最大値として再照合） |
| AG256のピン間組み合わせ遅延 | **目標10ns、暫定上限15ns** |

同一の入力変化基準で単純に120nsを配分すると、AG256以外に80.7nsを使うため残り39.3nsとなり、基板・負荷などの予備5～10nsを差し引いたCPLD予算は**29.3～34.3ns**。AG256を10nsとした場合の経路合計は90.7ns、15nsなら95.7ns（いずれもSFCの信号到着差、セットアップ・ホールド・出力有効化、基板条件は未算入）。特にSFC /ROMSELはアドレスと同時に到着するとは限らず、/CE起点の70ns経路の実際の利用可能時間は別途評価する。tACC・tCE・tOEは直列に足す遅延ではなく、信号ごとの到着時刻で比較する。

AG256資料のT_IN最大1.308ns、LUT最大1.111ns、T_DO最大2.140ns等は素子単体の内部遅延値であり、約10nsという例示計算は配置配線済みのSTA結果ではない。FastROM 120nsへの適合はAGM Supraのピン間STAとSFC実機タイミングによって確認する。

参考: [AG256/AG272公式ピン表・内部遅延](https://datasheet.lcsc.com/lcsc/1810010911_AGM-Microelectronics-AG256SL100_C133745.pdf)、[SN74LVC8T245](https://www.ti.com/product/SN74LVC8T245)、[74LVC245A](https://www.nexperia.com/products/analog-logic-ics/logic/buffers-inverters-transceivers/transceivers/serie/74lvc245a-74lvch245a)。
