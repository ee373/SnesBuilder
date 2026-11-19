# バス調停・UDB・アクセスタイミング

Rev.0.8 / 2026-11-19（AG256 + 8bitレベル変換版）。高速ROM/SRAMデコードおよびメモリ制御信号の唯一の駆動源はAG256SL100。PSoC UDBは通信、FIFO、所有権ハンドシェイクを担当する。

## 1. 排他的なMEM所有権

NOR/SRAMは23bitアドレス・8bitデータの3.3V共通MEMバスを使う。ARMとSFCが同時に駆動してはならない。所有権はPSoC UDB＋ARMファームウェアのFSMで管理し、SFCはWRAM実行中に変更要求を送る。

| 信号 | SFC所有 | 隔離 | ARM所有 |
|---|---|---|---|
| AG256 MEMアドレス15本 | 有効 | High-Z | High-Z |
| 74LVC245A #1（SFC A5–A12→MEM） | 有効 | High-Z | High-Z |
| PSoC MEM A0–A22 | High-Z | High-Z | GPIO駆動 |
| AG256 MEM /CE_ROM、/CE_RAM、/OE、/WE | SFCデコード | 全非選択 | PSoCからの4制御入力を選択 |
| PSoC MEM 4制御GPIO | AG256への入力、非選択 | AG256への入力、非選択 | AG256への入力、読書き駆動 |
| SN74LVC8T245データ経路 | SFCアクセス種別でDIR/OE | High-Z | High-Z |
| PSoC MEM D0–D7（P5） | High-Z | High-Z | 入出力 |
| PSoC SFC D0–D7（P0） | 通信・起動応答 | 通信可 | 通信可 |
| AG256 SPECIAL_SEL | 有効 | 有効 | 有効 |

AG256からNOR/SRAMへの4つのメモリ制御出力は常時接続し、**High-Z切替を行わない**。PSoCの同名4信号はAG256の入力にしか接続しない。AG256のメモリアドレス15出力とLVC245A #1の8出力のみ、SFC/ARM所有権に従いHigh-Z切替が必要となる。

## 2. 所有権制御入力と安全な状態

PSoC P4[6]からAG256へ渡すMEM_BUS_OEはSFC側MEMアドレス有効化に使用する。PSoC P4[0]をARM_MEM_ENABLEとして予約する設計契約とし、組合せでSFC・隔離・ARMの3状態を区別する。いずれも5V側PSoC GPIOから74LVC245Aを通じて3.3Vへ変換する。

| ARM_MEM_ENABLE | MEM_BUS_OE | AG256メモリ側動作 |
|---:|---:|---|
| 0 | 0 | 隔離（全/CE・/OE・/WE非選択、アドレスHigh-Z） |
| 0 | 1 | SFC所有（AG256アドレス＋LVC245A #1有効、SFCの制御を選択） |
| 1 | 0 | ARM所有（AG256アドレス＋LVC245A #1無効、PSoCの制御入力を選択） |
| 1 | 1 | 不正組合せとして隔離（フェイルセーフ） |

ROM_SIZE[0:2]=P4[1:3]は128KiB～8MiBの7段階容量、MODE_HILO=P4[4]はROM形式、EXTENSION_ENABLE=P4[7]は$5000通信の許可、BOOT_MODE=P15[3]は起動固定応答を担当する。BOOT_MODEはP15[3]からの独立信号である。AG256の回路出力が有効になる前はプルアップにより4つのメモリ制御を非選択にする。CFG0・MEM_BUS_OEの初期値が隔離を選ぶよう抵抗を設ける。

## 3. 所有権ハンドシェイク

FSMはISO→QUIET→CONFIG→GUARD→OWNERを設計契約とする。

1. SFCは本体WRAMへ制御コードを移し、カートリッジを参照するNMI/IRQ/DMAを停止してから$5000 BUS_CONTROLで要求する。
2. PSoCは新規MEMアクセスを停止し、進行中のストローブ完了を待つ。SFC所有ならMEM_BUS_OE=0に変更して隔離状態を確立する。
3. AG256アドレス15本、LVC245A #1、8T245を無効化し、メモリ制御4本を非選択にして必要な時間待つ。
4. PSoCはMEM GPIOのPRTx_BYP・ドライブモードを設定し、未準備のメモリストローブを出さないことを確認する。
5. ARM_MEM_ENABLE=1、MEM_BUS_OE=0としてARMへ所有権を与える。SFCへのSTATUS/REPLYに反映する。SFCへ返却する場合はARM_MEM_ENABLE=0で隔離してPSoC MEM GPIOをHigh-Zに戻してから、MEM_BUS_OE=1とする。

PSoCのMEM制御GPIOはAG256の入力なので出力High-Zの切替は不要だが、ARM所有へ切り替える前に**すべて非選択の値を確定**する。MEMアドレス・データの電気的競合を起こさないガード時間は実機で確定する。SFCのROM/SRAMアクセス中にバスを奪う方式は採用しない。

## 4. SFCアクセスごとの出力

| アクセス | ROM /CE | SRAM /CE | 8T245 | PSoC P0 |
|---|---|---|---|---|
| NOR読出し | 有効 | 無効 | A→B（MEM→SFC） | 入力 |
| SRAM読出し | 無効 | 有効 | A→B（MEM→SFC） | 入力 |
| SRAM書込み | 無効 | 有効 | B→A（SFC→MEM） | 入力 |
| $5000読出し | 無効 | 無効 | High-Z | 出力 |
| $5000書込み | 無効 | 無効 | High-Z | 入力 |
| 固定ブート6バイト読出し | 無効 | 無効 | High-Z | 出力 |
| ARM MEM所有 | PSoC入力を選択 | PSoC入力を選択 | High-Z | 通信可 |

SFCのSRAM書込みではDIR=Low（8T245 B→A）とデータセットアップを確保してからAG256が/WEを有効にする。ARMのNOR書込みはPSoCの/CE・/OE・/WE入力をAG256が選択する経路でのみ行う。外付けメモリの/CE・/OE・/WEには起動用プルアップを設け、SRAMのCE2には電源監視による保持保護を追加する。

## 5. 特殊領域と通信

AG256はSFC A0–A3とA12–A23、/ROMSEL・/RD・/WRをLVC245A #2～#4経由で受ける。SFC A4–A11はLVC245A #1からMEM A4–A11へ直結し、AG256へは入力しない。AG256のSPECIAL_SELはPSoC P3[4]へ接続する。PSoCはSFC A0–A3=P3[0:3]、/RD・/WR=P3[6:7]、/ROMSEL=P15[0]で16アドレスの通信またはブート固定応答を選択する。

$5000–$5FFFの通信レジスタはEXTENSION_ENABLEが有効な場合に16アドレス周期でミラーし、初期実装は12レジスタ、残り4アドレスは予約とする。

BOOT_MODEはP15[3]→LVC245A #5→AG256へ通知する。$00:FFFC–FFFDと$00:8000–8003の6バイトはPSoC UDBがP0から直接応答し、NOR/SRAMおよび8T245を同時に無効化する。SRAM BIOS窓$2F:6000–$2F:7FFFはBOOT_MODE中も維持する。PSoCが対象6アドレス以外でP0を出力しないようにする。

SPECIAL_SELはMEM所有権と独立して有効化するので、ARMがNOR/SRAMを利用していても$5000通信を継続できる。

## 6. PSoC UDBの担当

| 機能 | 実装場所 |
|---|---|
| HiROM/LoROM/Ex、128KiB–8MiB ROM容量マスク、SRAMデコード | AG256 |
| MEMアドレス23bit、データ8bit、MEM4制御GPIO | PSoC ARM＋GPIO。データ/アドレスのUDBラッチは不要 |
| 8T245 DIR/OE、#1 /OE、SPECIAL_SEL | AG256 |
| ブート6バイト固定応答、8bit読出しMUX、P0出力許可 | PSoC UDB |
| 16アドレス（実装12）の通信レジスタ、メールボックス | PSoC UDB＋ARM |
| 4バイトFIFO×2、2データパス、DMA要求、2FF CDC、IRQ | PSoC UDB＋DMA＋ARM |
| 所有権FSM・GPIO設定ACK | PSoC UDB＋ARM |
| microSD SPI Master | UDBを第一候補、DMA併用。必要に応じソフトウェアSPI |
| USB Full-Speed、DVDAC | PSoC専用HW＋DMA。UDBは原則不要 |
| SFC /RESET | PSoC P15[1]直接接続、オープンドレインLow/High-Z |

UDBの事前配分目安はブート2–4、通信3–5、双方向FIFO2–4、同期・FSM3–5、SPI1–3で計11–21個とする。これらは未合成の設計予算であり、24 UDBへの配置可能性・全PLD・内部ルーティングはCreatorで確認する。SFC読出しは事前準備したデータへの組み合わせ応答とし、FIFO更新イベントやARM通知は内部sys_clk領域で処理する。

## 7. タイミングと検証

FastROM 120ns、SlowROM 200nsを目標とする。SFC A→74LVC245A #2/#3→AG256→NOR A/CE（70ns）→8T245→SFC Dが最長経路候補である。SFC A5–A12→LVC245A #1→MEM Aへの経路は独立に測定する。AG256内の配置・配線、入力バッファ、/ROMSELの選択、NOR /OE起点15ns、8T245/OEと伝搬遅延を組み合わせてSTAする。

SRAM書込みの/WEとデータ、バス切替のHigh-Z有効時間、SPECIAL_SEL→PSoC UDB→P0応答、3.3V SPECIAL_SELの5V PSoC LVTTL入力条件を検証する。AGM SupraフィッタとPSoC Creatorの配置配線、ロジックアナライザ/オシロスコープ実測を完了判定に使用する。
