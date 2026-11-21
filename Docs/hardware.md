# SFCBuilder Rev.0.9 ハードウェア基本仕様

2026-11-21現行。AGM AG32VF407VGT6（LQFP100、3.3V、RV32IMAFC最大248MHz、AGRV2K約2112 LUT4）、NOR S29GL064S70TFI023（8MiB、x8、70ns）、SRAM LY62W1024SL-55SLI（128KiB、55ns）、74LVC245APW,118×5、SN74LVC8T245DBR×1、セーブ用SPI NOR GD25Q20ETIGR（256KiB）、CIC PIC12F629、USB Full-Speed、microSD SPI、PIN29/30からのステレオ3次1bit DSM出力（受動RC＋約22kHzアクティブLPF＋MCP6002）を採用する。

## SFCエッジ端子

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
| 31 / 62 | AUDIO L / R | AG32 PIN29/30のFPGA 1 bit DSM出力 → 受動RC → MCP6002による約22 kHzアクティブLPF |
| 24/25/55/56 | CIC | PIC12F629 |
| 27/58、5/36 | +5V、GND | 電源・接地 |

## レベル変換・3SB

74LVC245APW,118（U1–U4、U6）はTSSOP20、VCC PIN20=3.3V、GND PIN10、DIR PIN1=High（A→B）。CH0～7のA側ピンは2,3,4,5,6,7,8,9、B側ピンは18,17,16,15,14,13,12,11。未使用A入力はGND、対応B出力はNC。U2～U4の/OEはGND固定、U1/U6の/OEは3.3Vへプルアップする。

| IC | A側CH0–7 | B側CH0–7 | /OE PIN19 |
|---|---|---|---|
| U1 | SFC A11,A10,A9,A8,A7,A6,GND,GND | MEM A11,A10,A9,A8,A7,A6,NC,NC | AG32 PIN65 |
| U2 | SFC A5,A4,A3,A2,A1,A0,/RD,/WR | AG32 PIN36,35,34,33,32,31,38,39 | GND固定 |
| U3 | SFC A12,A13,A14,A15,A16,A17,A18,A19 | AG32 PIN47,46,45,44,43,42,41,40 | GND固定 |
| U4 | SFC A20,A21,A22,A23,/ROMSEL,GND,GND,GND | AG32 PIN54,53,52,51,48,NC,NC,NC | GND固定 |
| U6 | AG32 PIN55,56,57,58,59,60,GND,GND | MEM A11,A10,A9,A8,A7,A6,NC,NC | AG32 PIN66 |

U1とU6のB側CH0～5を同一MEM A11～A6へ接続する。SFC所有時にはU1だけを有効、CPU所有時にはU6だけを有効とし、切替時は両者を無効とする。U6へ向かうAG32 PIN55～60はCPU所有時だけ駆動し、それ以外はHi-Zにする。残る17本のアドレス線は通常の出力とする。

U5 SN74LVC8T245DBRはVCCA PIN1=5V、VCCB PIN23/24=3.3V、GND PIN11～13、SFC D0～D7→A側PIN3～10、MEM D0～D7→B側PIN21～14。DIR PIN2=SFC /RD（LowでMEM→SFC、HighでSFC→MEM）。/OE PIN22は5Vプルアップ、AG32 PIN67→N-MOSFETによるLow駆動で有効化する。AG32のMEM D0～D7はU5・NOR・SRAMと物理共通であり、FPGAの双方向出力許可を引き続き必要とする。

## SoCの固定機能と物理ピン

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
| 29/30 | FPGAデジタル出力 `DAC0_AUDIO_L` / `DAC1_AUDIO_R`。左右独立の8 MHz・3次1 bit DSM |
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

BOOT0=94・BOOT1=37は通常Low、UART復旧時に設定変更可能。JTAG兼用PIN77/89/90はSWDを確保したうえでGPIOへ設定する。MEMアドレス23本、SFCアドレス専用18本、データ8本、SFC制御5本、MEM制御4本、変換OE3本、SD4本、USB3本、DSM音声出力2本、UART2本、SWD2本、BOOT1予約1本を合計して**77本、予備1本**とする（従来75本にSPI NOR /CS・POWER_FAIL入力を追加）。固定電源/NC端子を含む100ピン表は[pinout.csv](pinout.csv)が正本である。

## 外部メモリとROM形式

外部パラレルNORはS29GL064S70TFI023（8 MiB、x8、70 ns、TSOP56）、SRAMはLY62W1024SL-55SLI（128 KiB、55 ns、SOIC32）とし、3.3 Vの共通MEM A0～A22・D0～D7へ接続する。NORはBYTE#をLowとし、MEM A0をNORのDQ15/A-1、MEM A1～A22をNOR A0～A21へ1 bitずらして配線する。SRAMはMEM A0～A12およびA16～A19を使用する。NOR /CE、SRAM /CE、共通/OE・/WEはAG32 PIN61～64で制御する。**NOR・SRAMのデータ端子・アドレス端子・制御端子の物理ピン表は[memory.md](memory.md)に集約し、本書では重複管理しない。** AG32側100ピン割当ては[pinout.csv](pinout.csv)を正本とする。

FPGAはLoROM・HiROM・ExLoROM・ExHiROM、128 KiB～8 MiBの7段階の容量マスク、WRAM/IOとセーブSRAMの優先デコードを実装する。非2冪容量のROMはローダが内容をNORへ事前展開し、RISC-VのAHB物理NORアクセスにはROMサイズマスクを掛けない。外部SRAM物理`0x1E000～0x1FFFF`の8 KiBは起動時のSFC BIOS領域とし、ゲーム実行後はBIOSオーバーレイを解除できる。電源断バックアップの対象は外部SRAM先頭120 KiBである。ROMのデコードと容量条件は[rom-compatibility.md](rom-compatibility.md)に、AHBの実装範囲は[bus.md](bus.md)に記載する。

## AG32内蔵FPGAとRISC-Vの接続

FPGAはROMマッピング、メモリ制御、AHBコントローラ、通信レジスタ、FIFO、起動固定応答、バス調停を担当する。RISC-VはUSB・microSD・ローダ・演算・音声を担当する。CPU→FPGA内部AHB `mem_ahb_*`、FPGA→CPU側`slave_ahb_*`、`ext_dma_*`、`local_int[3:0]`、sys_clock/bus_clock/resetnをPrepare LOGICの自動生成トップで接続する。外部MEM A0～A5・A12～A22の17本はFPGAのSFC/CPUアドレスMUX出力、A6～A11はU1/U6の所有権切替で駆動する。

CPU側AHBは本番RTLで制御レジスタ0x60000000～0x6000000C、SFC通信レジスタ0x60001000～0x60001030、音声PCMレジスタ0x60002000～0x60002008、NOR 0x61000000～0x617FFFFF、SRAM 0x62000000～0x6201FFFFにデコードする。詳細は[AHB実装・検証](verification/ahb-interface.md)を参照する。8bit MEMの16/32bitアクセスを複数バイトサイクルに変換し、HREADYOUTを使ってCPU側を待機させる。

**MEM D0～D7はSFCとNOR/SRAMとAG32で共通のため、CPU所有中にも独立したSFC通信データバスが存在するわけではない。** SFCの$5000特殊応答前にCPU側のメモリストローブを終了・停止し、NOR/SRAM/U5/AG32の出力方向を切替する。SFCのアクセス時間を任意に延長できないため、短いMEMサービス枠、NORプログラム中のBUSY、WRAM側待機プロトコルを含むアービタを実装する。所有権FSMはISOLATE→QUIET→CONFIGURE→GUARD→OWNER、切替時はU1/U6/U5を一時無効化してMEM制御を非選択とする。

内蔵Flashの共通ファームウェアが外部SRAM物理0x1E000～0x1FFFFへ8KiBのSFC用BIOSを展開し、ROM形式・MEM所有権設定後にSFC /RESETを解除する。FPGAは$00:FFFC/FFFDへ00/80、$00:8000～8003へ5C/00/60/2Fの固定6バイトを返し、SFCが`JML $2F6000`を実行する。通信窓は$00–$3F/$80–$BF:$5000–$5FFF、SFC A0～A5の64アドレス周期とし、有効化レジスタでゲームROMとの競合を避ける。通信レジスタは00 CPU_CONTROL、01 COMMAND、02 STATUS、03 REPLY、04 BUS_CONTROL、05 TX_DATA、06 RX_DATA、07 FIFO_STATUS、08 IRQ_CONTROL、09 IRQ_STATUS、0A/0B LENGTH、0C ERRORの13本とし、0D–3Fを予約する。CPU_CONTROL bit0は0=ゲーム固有処理の実行・再開、1=停止要求、STATUS bit3は停止完了を表す。共通ファームウェアは停止中も動作し、双方向FIFOは初期各4バイトとする。詳細は[communication.md](communication.md)を参照する。

## 性能と検証

SFCの通常NOR読出しにはRISC-Vソフトウェア処理やAHBを介在させず、FPGAの非同期アドレス変換・メモリ選択で処理する。SlowROM200nsを必須、FastROM120nsを設計目標とする。AG32向けRTLとピン割当ては現行[FPGAプロジェクト](../fpga/README.md)で実装し、Supra Nativeの合成・配置配線・同期STAは実施済み（CPU 240 MHz、BUSCLK/FIR 80 MHz、DSM 8 MHz）。[検証記録](verification/README.md)に本番の合格値を記載する。PCB上の波形・I/O電気特性・SlowROM/FastROM・電源・音声は実機で検証する。

## 電源断バックアップの接続

3.3V生成には既存MCP1825Sを使用し、5V側にDGH105Q5R5（5.5V・1F）を配置する。充電は47Ω・1Wで制限し、LM66100DCKR×2でSFC側への逆流防止および充電抵抗を経由しない放電経路を構成する。LMV331W5-7×1がSFC生5Vを検出し、保持3.3V基準の比較結果をAG32 PIN24のPOWER_FAILへ通知する。監視側分圧330kΩ／180kΩ、基準側100kΩ／100kΩ、出力プルアップ100kΩを使用し、監視側4.7nFのパッドは初期DNPとする。基準分圧点の追加コンデンサおよびHiCAP充電完了監視は設けない。詳細は[power-cic.md](power-cic.md)を参照する。

セーブ用SPI NOR GD25Q20ETIGRはSFC用8MiB NORと独立したICであり、microSDとSPI0 SCK/MOSI/MISOを共有する。PIN23の独立/CSはFPGA SPIデコーダがGPIO6 bits3:2に基づいて制御する。電源投入時に128KiB×2バンクから最新正常データをSRAMへ復元し、未使用バンクを消去する。電源断時にはAG32低クロックRunで最大120KiBを退避する。SPI NOR 0.1µFデカップリングを設ける。電源断中のU5・SFC側信号・MEMバス出力の安全状態を検証する。

## 内蔵Flash・RISC-V実行領域と音声回路

AG32内蔵FlashはSFCBuilder共通システムファームウェア（標準SFCプログラム、フォント、起動ローダ、セーブデータ退避・復元処理、FPGA構成データ）を保持する。外部8MiB NORにはSFCゲームROMとゲーム固有のRISC-V実行イメージを同梱し、起動時に後者をAG32内蔵SRAM128KiBの専用領域へ展開してそのエントリポイントへ移行する。常駐制御用RAMとアプリケーションRAMをリンカで分離し、電源断時の退避は内蔵Flashの共通コードで実施する。詳細は[firmware.md](firmware.md)を参照する。

FPGA音声系は64 kHz・16 bitステレオPCMを、共通の80 MHz `BUSCLK` で動く5相FIRで320 kHz・17 bitに変換する。水晶由来の8 MHz側で各サンプルを25クロック保持し、左右独立の3次1 bit DSMからPIN29/30へ出力する。受動RCとMCP6002によるアクティブLPFを経て、SFC AUDIO L/Rへ接続する。[音声処理と出力仕様](audio.md)
