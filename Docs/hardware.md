# SFCBuilder Rev.0.9 ハードウェア基本仕様

2026-11-19。AGM AG32VF407VGT6（LQFP100、3.3V、RV32IMAFC最大248MHz、AGRV2K約2112 LUT4）、NOR S29GL064S70TFI023（8MiB、x8、70ns）、SRAM LY62W1024SL-55SLI（128KiB、55ns）、74LVC245APW,118×5、SN74LVC8T245DBR×1、セーブ用SPI NOR GD25Q20ETIGR（256KiB）、CIC PIC12F629、USB Full-Speed、microSD SPI、ステレオDAC×2を採用する。

## ① SFCエッジ端子

| SFC端子 | 信号 | 接続 |
|---|---|---|
| 6–11 | A11–A6 | U1 CH0–5 |
| 12–17 | A5–A0 | U2 CH0–5 |
| 37–44 | A12–A19 | U3 CH0–7 |
| 45–48 | A20–A23 | U4 CH0–3 |
| 49 | /ROMSEL | U4 CH4 |
| 23 / 54 | /RD / /WR | U2 CH6 / CH7、/RDはU5 DIRにも接続 |
| 19–22 / 50–53 | D0–D3 / D4–D7 | U5 A側 |
| 18 | /IRQ | AG32 PIN26→オープンドレインLow回路 |
| 26 | /RESET | 5V⇄3.3V双方向オープンドレイン変換→AG32 PIN7 |
| 31 / 62 | AUDIO L / R | AG32 DAC0 PIN29 / DAC1 PIN30→LPF/MCP6002 |
| 24/25/55/56 | CIC | PIC12F629 |
| 27/58、5/36 | +5V、GND | 電源・接地 |

## ② レベル変換・3SB

74LVC245APW,118（U1–U4、U6）はTSSOP20、VCC PIN20=3.3V、GND PIN10、DIR PIN1=High（A→B）。CH0～7のA側ピンは2,3,4,5,6,7,8,9、B側ピンは18,17,16,15,14,13,12,11。未使用A入力はGND、対応B出力はNC。U2～U4の/OEはGND固定、U1/U6の/OEは3.3Vへプルアップする。

| IC | A側CH0–7 | B側CH0–7 | /OE PIN19 |
|---|---|---|---|
| U1 | SFC A11,A10,A9,A8,A7,A6,GND,GND | MEM A11,A10,A9,A8,A7,A6,NC,NC | AG32 PIN65 |
| U2 | SFC A5,A4,A3,A2,A1,A0,/RD,/WR | AG32 PIN36,35,34,33,32,31,38,39 | GND固定 |
| U3 | SFC A12,A13,A14,A15,A16,A17,A18,A19 | AG32 PIN47,46,45,44,43,42,41,40 | GND固定 |
| U4 | SFC A20,A21,A22,A23,/ROMSEL,GND,GND,GND | AG32 PIN54,53,52,51,48,NC,NC,NC | GND固定 |
| U6 | AG32 PIN55,56,57,58,59,60,GND,GND | MEM A11,A10,A9,A8,A7,A6,NC,NC | AG32 PIN66 |

U1とU6のB側CH0～5を同一MEM A11～A6へ接続する。SFC所有時にはU1だけを有効、CPU所有時にはU6だけを有効とし、切替時は両者を無効とする。AG32のアドレス出力23本はすべて通常OUTPUTとして実装する。

U5 SN74LVC8T245DBRはVCCA PIN1=5V、VCCB PIN23/24=3.3V、GND PIN11～13、SFC D0～D7→A側PIN3～10、MEM D0～D7→B側PIN21～14。DIR PIN2=SFC /RD（LowでMEM→SFC、HighでSFC→MEM）。/OE PIN22は5Vプルアップ、AG32 PIN67→N-MOSFETによるLow駆動で有効化する。AG32のMEM D0～D7はU5・NOR・SRAMと物理共通であり、FPGAの双方向出力許可を引き続き必要とする。

## ④ SoCの固定機能と物理ピン

| AG32 PIN | 役割 |
|---|---|
| 1–5 | MEM A18–A22 |
| 7 | SFC /RESET変換回路 |
| 12/13 | 8MHz水晶 OSC_IN/OUT |
| 14 | NRST |
| 15–18 | SD SCK/MOSI/MISO//CS |
| 23 | SPI NOR /CS（microSDとSPI共有） |
| 24 | 電源断検出 POWER_FAIL入力 |
| 25 | GPIO予備1本 |
| 26 | SFC /IRQ用MOSFET制御 |
| 29/30 | DAC0 L / DAC1 R |
| 31–36 | SFC A0–A5 |
| 37 | BOOT1 |
| 38/39 | SFC /RD・/WR |
| 40–47 | SFC A19–A12（逆順） |
| 48 | SFC /ROMSEL |
| 51–54 | SFC A23–A20（逆順） |
| 55–60 | MEM A11–A6 → U6 |
| 61–64 | MEM /CE_ROM、/CE_RAM、/OE、/WE |
| 65–67 | U1 /OE、U6 /OE、U5 /OE制御 |
| 68/69 | UART0 TX/RX |
| 70/71 | USB D−/D+ |
| 72/76 | SWDIO/SWCLK |
| 77 | USB VBUS分圧入力 |
| 78–85 | MEM D0–D7（双方向） |
| 86–91 | MEM A0–A5 |
| 92/93 | MEM A12/A13 |
| 94 | BOOT0 |
| 95–98 | MEM A14–A17 |

BOOT0=94・BOOT1=37は通常Low、UART復旧時に設定変更可能。JTAG兼用PIN77/89/90はSWDを確保したうえでGPIOへ設定する。MEMアドレス23本、SFCアドレス専用18本、データ8本、SFC制御5本、MEM制御4本、変換OE3本、SD4本、USB3本、DAC2本、UART2本、SWD2本、BOOT1予約1本を合計して**77本、予備1本**とする（従来75本にSPI NOR /CS・POWER_FAIL入力を追加）。固定電源/NC端子を含む100ピン表は[pinout.csv](pinout.csv)が正本である。

## ③ 外部メモリ

NORはS29GL064S70TFI023（8MiB、x8、70ns、TSOP56）、SRAMはLY62W1024SL-55SLI（128KiB、55ns、SOIC32）。3.3V共通MEM A0～A22・D0～D7を使用する。NOR BYTE# PIN53=GNDに固定し、MEM A0→NOR DQ15/A-1、MEM A1～A22→NOR A0～A21に1bitシフトして接続する。

| MEM | NOR信号 | NOR物理PIN |
|---|---|---:|
| A0 | DQ15/A-1 | 51 |
| A1 | A0 | 31 |
| A2 | A1 | 26 |
| A3 | A2 | 25 |
| A4 | A3 | 24 |
| A5 | A4 | 23 |
| A6 | A5 | 22 |
| A7 | A6 | 21 |
| A8 | A7 | 20 |
| A9 | A8 | 10 |
| A10 | A9 | 9 |
| A11 | A10 | 8 |
| A12 | A11 | 7 |
| A13 | A12 | 6 |
| A14 | A13 | 5 |
| A15 | A14 | 4 |
| A16 | A15 | 3 |
| A17 | A16 | 54 |
| A18 | A17 | 19 |
| A19 | A18 | 18 |
| A20 | A19 | 11 |
| A21 | A20 | 12 |
| A22 | A21 | 15 |

NOR DQ0～7物理PIN35,37,39,41,44,46,48,50をMEM D0～D7へ、/CE PIN32←AG32 PIN61、/OE PIN34←PIN63、/WE PIN13←PIN64、VCC PIN43・VIO PIN29は3.3V。/RESET PIN14は通常High、WP#/ACC PIN16は通常動作電位に設定する。

SRAM A0～A12←MEM A0～A12、SRAM A13～A16←MEM A16～A19。SRAM /CE1 PIN22←AG32 PIN62、/OE PIN24←PIN63、/WE PIN29←PIN64、CE2 PIN30は3.3Vへ接続し、電源断時の書込み停止・復元時の選択制御はAG32/FPGAのMEM制御で扱う。SRAM D0～7物理PIN13,14,15,17,18,19,20,21←MEM D0～7、VCC PIN32は3.3V、GND PIN16=GND。SRAMアドレス物理端子はA0=12、A1=11、A2=10、A3=9、A4=8、A5=7、A6=6、A7=5、A8=27、A9=26、A10=23、A11=25、A12=4、A13=28、A14=3、A15=31、A16=2。

FPGAがHiROM/LoROM/ExHiROM/ExLoROMをデコードする。ROM_SIZEの7段階は128KiB（物理A17–A22を0）、256KiB（A18–A22を0）、512KiB（A19–A22）、1MiB（A20–A22）、2MiB（A21–A22）、4MiB（A22）、8MiB（マスクなし）とする。非2冪ROMはローダが元ROMの反復規則に沿ってNORへ事前展開する。SRAMにROMマスクは適用しない。HiROM基本アドレスはMEM A0–A21←SFC A0–A21、LoROM基本はMEM A0–A14←SFC A0–A14、MEM A15–A21←SFC A16–A22とし、MEM A22をEx領域の選択に使用する。WRAM/IO/特殊領域とSRAMの優先デコードも行う。SRAM物理0x1E000～0x1FFFFの8KiBへBIOSを配置する。

## FPGA/RISC-Vの接続

FPGAはROMマッピング、メモリ制御、AHBコントローラ、通信レジスタ、FIFO、起動固定応答、バス調停を担当する。RISC-VはUSB・microSD・ローダ・演算・音声を担当する。CPU→FPGA内部AHB `mem_ahb_*`、FPGA→CPU側`slave_ahb_*`、`ext_dma_*`、`local_int[3:0]`、sys_clock/bus_clock/resetnをPrepare LOGICの自動生成トップで接続する。外部MEM A0～A5・A12～A22の17本はFPGAのSFC/CPUアドレスMUX出力、A6～A11はU1/U6の所有権切替で駆動する。

CPUのAHBメモリ窓候補は制御0x60000000、FIFO0x60001000、NOR8MiB=0x61000000、SRAM128KiB=0x62000000であり、AG32の実際の外部AHB領域と生成トップのデコードに照合する。8bit MEMの16/32bitアクセスを複数バイトサイクルに変換し、HREADYOUTを使ってCPU側を待機させる。

**MEM D0～D7はSFCとNOR/SRAMとAG32で共通のため、CPU所有中にも独立したSFC通信データバスが存在するわけではない。** SFCの$5000特殊応答前にCPU側のメモリストローブを終了・停止し、NOR/SRAM/U5/AG32の出力方向を切替する。SFCのアクセス時間を任意に延長できないため、短いMEMサービス枠、NORプログラム中のBUSY、WRAM側待機プロトコルを含むアービタを実装する。所有権FSMはISOLATE→QUIET→CONFIGURE→GUARD→OWNER、切替時はU1/U6/U5を一時無効化してMEM制御を非選択とする。

電源投入後RISC-Vが外部SRAM物理0x1E000～0x1FFFFへ8KiBのSFC用BIOSを展開し、ROM形式・MEM所有権設定後にSFC /RESETを解除する。FPGAは$00:FFFC/FFFDへ00/80、$00:8000～8003へ5C/00/60/2Fの固定6バイトを返し、SFCが`JML $2F6000`を実行する。通信窓は$00–$3F/$80–$BF:$5000–$5FFF、SFC A0～A5の64アドレス周期とし、有効化レジスタでゲームROMとの競合を避ける。初期12レジスタは00 COMMAND、01 STATUS、02 REPLY、03 BUS_CONTROL、04 TX_DATA、05 RX_DATA、06 FIFO_STATUS、07 IRQ_CONTROL、08 IRQ_STATUS、09/0A LENGTH、0B ERRORとし、0C–3Fを予約する。双方向FIFOは初期各4バイトを想定する。

## 性能と検証

SFCの通常NOR読出しにはRISC-Vソフトウェア処理やAHBを介在させず、FPGAの非同期アドレス変換・メモリ選択で処理する。SlowROM200nsを必須、FastROM120nsを設計目標とする。FPGAピン合法性、双方向データI/O、Supra Native合成、非同期入出力STA、AHBバス、MEM競合、電源/実機タイミングは**後工程で検証する事項**であり、合格済みとは扱わない。

## 電源断バックアップの接続

3.3V生成には既存MCP1825Sを使用し、5V側にDGH105Q5R5（5.5V・1F）を配置する。充電は47Ω・1Wで制限し、LM66100DCKR×2でSFC側への逆流防止および充電抵抗を経由しない放電経路を構成する。LMV331W5-7×1がSFC生5Vを検出し、保持3.3V基準の比較結果をAG32 PIN24のPOWER_FAILへ通知する。監視側分圧330kΩ／180kΩ、基準側100kΩ／100kΩ、出力プルアップ100kΩを使用し、監視側4.7nFのパッドは初期DNPとする。基準分圧点の追加コンデンサおよびHiCAP充電完了監視は設けない。詳細は[power-cic.md](power-cic.md)を参照する。

セーブ用SPI NOR GD25Q20ETIGRはSFC用8MiB NORと独立したICであり、microSDとSPI SCK/MOSI/MISOを共有し、PIN23の独立/CSで選択する。電源投入時に128KiB×2バンクから最新正常データをSRAMへ復元し、未使用バンクを消去する。電源断時にはAG32低クロックRunで最大120KiBを退避する。SPI NOR 0.1µFデカップリングを設ける。電源断中のU5・SFC側信号・MEMバス出力の安全状態を検証する。
