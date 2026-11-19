# PSoC UDB・AG256 CPLD 資源評価

Rev.0.8 / 2026-11-19。高速アドレス・/CE/OE/WEをAGM AG256SL100へ割り当て、PSoC 5LP UDBを通信・FIFO・所有権ハンドシェイクへ集中させる。

## 1. 資源の物理上限と論理I/O予算

| デバイス | 資源 | 数量 |
|---|---|---:|
| PSoC CY8C5287AXI-LP095 | UDB / PLD / PLDマクロセル / データパス | 24 / 48 / 192 / 24 |
| AG256SL100 | LUT・論理要素 | 256 |
| AG256SL100 | ユーザーI/O | 80 |
| AG256SL100 | 専用JTAG | 4端子 |

AG256の論理I/Oは**入力31本、出力23本、計54/80本**。電圧変換はSN74LVC8T245DBR ×1、74LVC245APW,118 ×5であり、後者は40レーンのうち38レーンを使用する。旧LC4064Vの64マクロセル/50 I/O+専用入力4本の予算は本版には適用しない。実際のLUT収容率とI/O配置はSupraの合成・フィッティングで測定する。

## 2. 担当回路

| 機能 | AG256 | PSoC |
|---|---|---|
| SFC→NORのROM4形式、SRAM2形式デコード | 担当 | なし |
| メモリアドレス15本のHigh-Z | 担当 | FSM制御 |
| MEM /CE_ROM、/CE_RAM、/OE、/WE | **唯一のメモリ側出力** | 4本の制御**入力をAG256に提供** |
| 8T245 DIR・/OE、LVC245A #1 /OE | 担当 | モード・所有権制御 |
| BOOT_MODE | PSoC P15[3]から入力 | 専用出力 |
| $5000上位選択とブート候補 | SPECIAL_SEL | 下位デコード・固定値応答 |
| メールボックス、IRQ、CDC・双方向4byte FIFO | なし | UDBデータパス＋DMA |
| microSDのSCK/MOSI//CS | **経由しない** | PSoC→LVC245A #5→microSD |
| USB、DVDAC | なし | 専用HW・DAC・DMA |

ROM容量のミラーはゲームローダがNOR書込み時に展開するため、CPLD/UDB内に容量別ミラー演算回路を設けない。

## 3. 所有権と論理実装

PSoC CFG0のARM_MEM_ENABLEとP4[7]のMEM_BUS_OEをAG256へ入力し、(0,0)=隔離、(0,1)=SFC、(1,0)=ARM、(1,1)=フェイルセーフ隔離とする。AG256のMEM制御4出力はHigh-Z化せず隔離中はすべて非選択、ARM所有時はPSoCの4入力を選択する。AG256のMEMアドレス15本とLVC245A #1の/OEは所有権に従ってHigh-Zとする。

Rev0.8のPSoC UDBには通信12レジスタ、予約20アドレス、BOOT6バイト応答、所有権FSM、2個の4byte FIFO、CDC、IRQ、DMA要求を実装する。Rev0.7のPythonモデルPASSは参考であり、Rev0.8の合成/HDLテスト完了を意味しない。

## 4. 合成とタイミング検証

AGM SupraでROM4形式、SRAM2形式、SPECIAL_SEL、制御信号選択MPX、8T245 DIR/OE、LVC245A #1 OE、安全な隔離モードを合成する。レポートには使用LUT・I/O・内部ルート・ピン配置・最大遅延を残す。最長パスはSFC→74LVC245A→AG256→NOR 70ns→8T245→SFC Dと、SFC /ROMSEL→AG256→NOR /CE経路である。AG256の内部遅延値だけで120ns合格とは扱わない。

PSoC CreatorではP0/P5、P15[3] BOOT_MODE、P4[7] MEM_BUS_OE、P12/P15のMEM制御入力生成、DVDAC、SWD、USB、FIFO、DMAを検証する。Supraのライセンス・JTAG治具・書込み方法も初回試作前に確認する。

## 5. 現在の実装状態

必要信号と54 I/Oの論理予算、および8bit変換IC6個の38レーン割当てまで設計済み。AG256用RTLの合成/フィッティング、PSoC Creatorの再配置、HDLシミュレーション、STA、実機測定は未完了である。
