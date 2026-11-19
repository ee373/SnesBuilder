# ハードウェア基本仕様

Rev0.8改訂案 / 2026-11-19。採用部品は維持し、SFC端子配列に基づくピン再配置、7段階ハードウェアROMミラー、UDB機能分担、FastROM遅延予算を反映する。CPLD/PSoC Creatorの合成・配置配線、実機タイミング測定は未実施。

## 1. 基本構成

| 項目 | 採用仕様 |
|---|---|
| 機種 | SFC / SNES、5Vカートリッジバス |
| MCU | PSoC 5LP CY8C5287AXI-LP095、Cortex-M3 最大80MHz、内蔵Flash 256KiB / SRAM 64KiB |
| PSoCデジタル資源 | 24 UDB、48 PLD、192マクロセル、24データパス |
| CPLD | AGM AG256SL100、256 LUT/LE、80ユーザーI/O、3.3V LQFP100 |
| SFC/MEMデータ変換 | SN74LVC8T245DBR ×1、5V↔3.3V 8bit |
| SFCアドレス・制御変換 | Nexperia 74LVC245APW,118 ×5、5V入力→3.3V出力固定 |
| ROM | S29GL064S70TFI023、8MiB、x8、70ns NOR |
| RAM | CY62128EV30LL-45SXI、128KiB、45ns SRAM、CR2032保持 |
| マッピング | HiROM・LoROM・ExHiROM・ExLoROM |
| ROM容量 | 128/256/512KiB、1/2/4/8MiBの7段階をAG256でマスク |
| 非2冪ROM容量 | ARMローダが元カートリッジ規則によりNOR上で次の2冪容量へ展開 |
| SFC通信 | $5000–$5FFF、下位16アドレスをミラー、初期実装12レジスタ、双方向4バイトFIFO、IRQ/DMA |
| USB・記録媒体 | USB Full-Speed 12Mbpsデバイス（PCがホスト）、microSD SPI |
| 音声 | PSoC DVDAC 10bit/32kHz初期目標→LPF/MCP6001→SFC外部音声L/R |
| 起動 | ARMが内蔵FlashからSRAM末尾8KiBへBIOS展開、UDBが6バイト固定応答 |
| 遅延条件 | SlowROM 200ns以内必須、FastROM 120ns以内は設計目標 |
| PCB | 4層・1.2mm FR-4、ENIG、外部リードIC、手はんだ試作 |

## 2. 各デバイスの担当と信号の方向

AG256はSFCのROM/SRAMデコード、HiROM/LoROM・Ex変換、ROM容量7段階マスク、メモリ側アドレス15本の生成、4本のメモリ制御出力、8T245 DIR/OE、LVC245A #1 /OE、特殊領域選択を担当する。通常のROM読出しはPSoC/UDBを通らない。

PSoCのARMはNOR消去・書込み、ゲームローダ、BIOS、メモリ所有権、USB、microSD、セーブ同期、ゲーム処理を担当する。UDBはブート6バイト、通信12レジスタ（16アドレス窓）、双方向FIFO、非同期CDC、IRQ、MEM所有権ハンドシェイク、必要に応じSPI Masterを担当する。外部MEM A0–A22・D0–D7はARM＋GPIOで扱い、23bitアドレスラッチをUDB内に設けない。USBとVDAC/DVDACは専用ハードウェアを使用する。

## 3. SFC端子基準の接続・配置

SFCのA11～A0は端子6～17、A12～A23は37～48に並ぶ。A4～A11の連続8本をLVC245A #1にまとめてMEM A4～A11へ送り、A0～A3とA12～A23は#2/#3経由でAG256へ入力する。AG256はMEM A0～A3/A12～A22を生成する。SFC D0～D7は8T245とPSoC P0に接続するが、同時に駆動してはならない。

| 接続 | SFC所有時 | ARM所有時 |
|---|---|---|
| MEM A0–A3 | AG256 | PSoC P2[0:3] |
| MEM A4–A11 | LVC245A #1 | PSoC P2[4:7] / P6[0:3] |
| MEM A12–A15 | AG256 | PSoC P6[4:7] |
| MEM A16–A21 | AG256 | PSoC P1[2:7] |
| MEM A22 | AG256 | PSoC P12[6] |
| MEM D0–D7 | SFC側8T245 | PSoC P5[0:7] |
| NOR /CE、SRAM /CE、共通/OE・/WE | AG256単独出力 | AG256単独出力（ARMのGPIO入力4本を選択） |

MEMアドレス23本、データ8本は排他所有とし、SFC所有時はARM側GPIOをHigh-Z、ARM所有時はAG256のアドレス15本・#1・8T245をHigh-Zにする。制御4出力はAG256のみが駆動する。[cpld.md](cpld.md)参照。

物理的な部品配置は、SFC端子からLVC245A/8T245、AG256、NOR/SRAMへ向かう短い高速経路を中心に組み、PSoCをAG256の制御入力側へ配置する。AG256のI/Oピン番号は[cpld-pinout.csv](cpld-pinout.csv)に定義する。

## 4. PSoC 100ピン配置と電源ドメイン

電源はVDDIO0/VDDIO3=5V、VDDIO1/VDDIO2=3.3V、VDDD/VDDA=5V、USB P15[6:7]はUSB専用。全ピンの物理番号は[pinout.csv](pinout.csv)を正本とする。

| ポート | 使用 |
|---|---|
| P0[0:7] | SFC D0–D7（5V、ブート/通信のみ出力） |
| P1[0:1] | SWDIO/SWDCK（3.3V） |
| P1[2:7] | MEM A16–A21（3.3V） |
| P2[0:7] | MEM A0–A7（3.3V） |
| P3[0:3] | **SFC A0–A3（5V）** |
| P3[4] | **AG256 SPECIAL_SEL入力（5VドメインのLVTTL入力）** |
| P3[5] | **予備GPIO** |
| P3[6:7] | SFC /RD、/WR（5V） |
| P4[0] | ARM_MEM_ENABLE |
| P4[1:3] | ROM_SIZE[0:2] |
| P4[4] | MODE_HILO |
| P4[5] | DVDAC出力（5V） |
| P4[6] | MEM_BUS_OE |
| P4[7] | EXTENSION_ENABLE |
| P5[0:7] | MEM D0–D7（3.3V） |
| P6[0:7] | MEM A8–A15（3.3V） |
| P12[0:2] | SD SCK/MOSI//CS（5V→#5→3.3V） |
| P12[3] | SD MISO（5V SIO、3.3V入力のため差動しきい値を使用） |
| P12[4] | ARM MEM /WE |
| P12[5] | USB VBUS検出（3.3V SIO、5.5V耐入力を利用） |
| P12[6] | MEM A22（3.3V） |
| P12[7] | ARM MEM /CE_RAM |
| P15[0:3] | SFC /ROMSEL、**SFC /RESET直接接続**、SFC /IRQ、BOOT_MODE |
| P15[4:5] | ARM MEM /CE_ROM、ARM MEM /OE（3.3V） |
| P15[6:7] | USB D+、D− |

SFC /RESETはSFCコネクタ26番→PSoC P15[1]（物理43番）の直接接続とし、レベル変換IC・AG256を経由しない。PSoCがオープンドレインLowで保持し、High-Z解除する。P0/P5の独立8bitバス、SFC A0–A3とSPECIAL_SEL・/RD・/WRのP3集中配置、MEM A16–A22の物理的な近接を維持する。PSoC GPIOは**71/72使用、1本予備**。

SIOの3.3V信号判定とVBUS耐圧、P4[5]のDVDACルート、SWD、UDBのP0データ出力許可はPSoC Creatorで検証する。

## 5. ブート・通信・所有権

ARMがSRAM物理0x1E000～0x1FFFFへ8KiB BIOSを展開してからSFCのリセットを解放する。BOOT_MODE中、PSoC UDBは$00:FFFC/$00:FFFDへ00/80、$00:8000–8003へ5C/00/60/2Fを直接返して`JML $2F6000`させる。AG256は特殊応答中のNOR/SRAMと8T245を非選択にする。

通信レジスタは$5000～$500Fの16アドレスを$5000～$5FFFへミラーし、12レジスタを実装、4アドレスを予約とする。ARMがMEMバスを所有している間もP0経由のFIFO/コマンド通信は利用できる。

所有権はARM_MEM_ENABLE/MEM_BUS_OEの組み合わせで、00=隔離、01=SFC、10=ARM、11=フェイルセーフ隔離とする。WRAM実行中の静止要求→双方High-Z→GPIO設定→ガード→所有権確定の順序を保証する。

## 6. 重要な実装・タイミング条件

FastROM 120nsの単純配分では、LVC245A 6.3ns、NOR70ns、8T245 4.4nsを差し引くとAG256と余裕のために39.3ns残る。基板等5～10nsを仮置きしたAG256の計画予算は29.3～34.3nsで、ピン間遅延10nsを目標、15nsを暫定上限とする。この配分は同時入力変化を仮定した概算であり、/ROMSELの遅れ、/OEの制御、SFCセットアップと基板負荷を含む全経路STAではない。

NORはBYTE#=Lowのx8動作で、MEM A0→DQ15/A-1、MEM A1～A22→NOR A0～A21に1bitシフトして配線する。物理データはNOR DQ0～DQ7を使用する。NORコマンドアドレスとARMローダのバイト指定もこの配線と一致させる。

SRAMバックアップ、3.3V LDO 500mA、USB逆給電防止、AG256/レベル変換ICの電源投入時High-Z、CICとリセット再アサート、SFCデータバス排他、NORのFastROM 120nsは回路図・ツール・実機で検証する。
