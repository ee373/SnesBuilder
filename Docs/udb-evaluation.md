# PSoC UDB・CPLD 資源評価

Rev.0.8 / 2026-11-19。本リビジョンではLC4064V CPLDにメモリ高速デコードとアドレス変換を割り当て、PSoC 5LPのUDBを通信・FIFO・バス所有権制御へ集中させる。

## 1. 資源の物理上限

| デバイス | 資源 | 数量 |
|---|---|---:|
| PSoC CY8C5287AXI-LP095 | UDB | 24 |
| PSoC | PLD | 48 |
| PSoC | PLDマクロセル | 192 |
| PSoC | UDBデータパス | 24 |
| LC4064V-75TN100C | マクロセル | 64 |
| LC4064V-75TN100C | 汎用I/O | 64 |
| LC4064V-75TN100C | 専用入力 | 10 |

Rev0.8の必要信号数はCPLD汎用I/O **50本**、PSoC CFG[3:0]向け専用入力4本である。[cpld.md](cpld.md)の集計を採用する。50汎用I/Oの割当ては論理設計の信号表であり、Latticeフィッタによる物理端子割当て完了を意味しない。

## 2. 担当回路

| 機能 | CPLD | PSoC UDB |
|---|---|---|
| SFC→NORアドレス変換（HiROM/LoROM/Ex） | 担当 | なし |
| NOR/SRAMアドレスと/CE・/OE・/WE | 担当 | ARM所有時のGPIOとハンドシェイク |
| 16T245グループ1 DIR・/OE | 担当 | モード・所有権要求 |
| 16T245グループ2 /OE | 所有権と連動 | PSoC P15[3]のGPIO |
| $5000高位選択・ブート候補 | SPECIAL_SELを生成 | 下位デコードと実データ応答 |
| 通信レジスタ12個と予約20アドレス | なし | 担当 |
| メールボックス、IRQ、CDC | なし | 担当 |
| 双方向各4byte FIFO | なし | Datapath F0/F1等 |
| バス所有権FSM | OE制御を実行 | 状態管理・GPIO CONFIG ACK |
| microSD SCK/MOSI//CSの電圧変換 | 担当 | SPI波形の生成 |
| USB、DVDAC | なし | USB専用ハードウェア/DMA/DACと連携 |

ROMの容量ミラーリングはロード時のNORイメージ事前展開とし、実行時のCPLDおよびUDBへ容量別ミラー演算器を追加しない。

## 3. UDBの実装・計測計画

双方向FIFOは各方向1つの8bitデータパスを初期方針とし、容量4byte、Status/Controlレジスタ、トグル/ACK CDC、一時保持、ARM/DMAアクセスを含める。バス所有権FSM、特殊領域の固定6バイトデコード、32アドレスの通信レジスタ、DMA要求、SFC /IRQをPSoC Creatorで合成する。

CPLDへの機能移管によりUDB内のROMマッピング/メモリ選択が不要になるが、追加のSPECIAL_SEL入力、P0/P5端子設定、メモリGPIO所有権制御があるため、**Rev0.8のPLD使用量は新しい完全なRTL/Creatorプロジェクトの合成値を採用する**。単独のFF数や旧RTLの組み合わせ式数をそのままPLD使用数とはみなさない。

SPIはPSoCソフトウェアまたはUDBで生成する。FastROM/SFC通信/FIFOと資源・DMAが競合する場合はARMによるGPIOソフトウェアSPIを基本とする。SPIの出力レベル変換はCPLDが担当する。

## 4. CPLDの検証

64マクロセル・4 GLBの範囲に、ROM4形式、SRAM2形式、SPECIAL_SEL、メモリ出力OE、DIR/OE、microSD変換を収容する。アドレス・/CE・/OE・/WE出力のピン間STA、プロダクトターム・論理深度、GLBのルーティング、GOEとSPECIAL_SELの独立駆動をフィッタで確認する。

最長パスはSFCアドレス→CPLD→NOR 70ns→16T245→SFCデータと、SFC /ROMSEL→CPLD→NOR /CE→データである。デバイスの7.5ns速度グレードだけでは120ns FastROMの達成判定に使わない。

## 5. 現在の検証状態

設計済みなのは論理的な信号役割、CPLD I/O本数予算、PSoCのポート別再割当てである。Rev0.8についてはCPLDの合成・フィッタ結果、PSoC Creator配置、HDLテストベンチ実行、タイミング解析、実機測定のいずれも未完了である。

評価用の旧リビジョンRTLは[verilog/README.md](verilog/README.md)に独立して保存されている。Rev0.8の実装正本には使用しない。
