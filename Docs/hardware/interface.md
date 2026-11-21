# Rev.0.9 — SFCエッジ端子とAG32インターフェース

本書はAGM AG32VF407VGT6とSFCエッジ端子の接続、および内蔵FPGAとRISC-Vの接続境界を記載する。100ピンすべての割当ては[物理ピン表](pinout.csv)、外付け変換ICの/OE・DIRは[レベル変換仕様](level-shifters.md)を唯一の正本とする。

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

## AG32内蔵FPGAとRISC-Vの接続

FPGAはROMマッピング、メモリ制御、AHBコントローラ、通信レジスタ、FIFO、起動固定応答、バス調停を担当する。RISC-VはUSB・microSD・ローダ・演算・音声を担当する。CPU→FPGA内部AHB `mem_ahb_*`、FPGA→CPU側`slave_ahb_*`、`ext_dma_*`、`local_int[3:0]`、sys_clock/bus_clock/resetnをPrepare LOGICの自動生成トップで接続する。外部MEM A0～A5・A12～A22の17本はFPGAのSFC/CPUアドレスMUX出力、A6～A11はU1/U6の所有権切替で駆動する。

CPU側AHBは本番RTLで制御レジスタ0x60000000～0x6000000C、SFC通信レジスタ0x60001000～0x60001030、音声PCMレジスタ0x60002000～0x60002008、NOR 0x61000000～0x617FFFFF、SRAM 0x62000000～0x6201FFFFにデコードする。詳細は[AHB実装・検証](../verification/ahb.md)を参照する。8bit MEMの16/32bitアクセスを複数バイトサイクルに変換し、HREADYOUTを使ってCPU側を待機させる。

**MEM D0～D7はSFCとNOR/SRAMとAG32で共通のため、CPU所有中にも独立したSFC通信データバスが存在するわけではない。** SFCの$5000特殊応答前にCPU側のメモリストローブを終了・停止し、NOR/SRAM/U5/AG32の出力方向を切替する。SFCのアクセス時間を任意に延長できないため、短いMEMサービス枠、NORプログラム中のBUSY、WRAM側待機プロトコルを含むアービタを実装する。所有権FSMはISOLATE→QUIET→CONFIGURE→GUARD→OWNER、切替時はU1/U6/U5を一時無効化してMEM制御を非選択とする。

内蔵Flashの共通ファームウェアが外部SRAM物理0x1E000～0x1FFFFへ8KiBのSFC用BIOSを展開し、ROM形式・MEM所有権設定後にSFC /RESETを解除する。FPGAは$00:FFFC/FFFDへ00/80、$00:8000～8003へ5C/00/60/2Fの固定6バイトを返し、SFCが`JML $2F6000`を実行する。通信窓は$00–$3F/$80–$BF:$5000–$5FFF、SFC A0～A5の64アドレス周期とし、有効化レジスタでゲームROMとの競合を避ける。通信レジスタは00 CPU_CONTROL、01 COMMAND、02 STATUS、03 REPLY、04 BUS_CONTROL、05 TX_DATA、06 RX_DATA、07 FIFO_STATUS、08 IRQ_CONTROL、09 IRQ_STATUS、0A/0B LENGTH、0C ERRORの13本とし、0D–3Fを予約する。CPU_CONTROL bit0は0=ゲーム固有処理の実行・再開、1=停止要求、STATUS bit3は停止完了を表す。共通ファームウェアは停止中も動作し、双方向FIFOは初期各4バイトとする。詳細は[communication.md](../fpga/communication.md)を参照する。

## 関連仕様

外部NOR/SRAMの部品側ピンは[メモリ配線](memory-devices.md)、ROM形式は[FPGAマッピング](../fpga/rom-mapping.md)、MEM所有権とMMIOは[FPGAバス](../fpga/bus.md)、電源とCICは[電源仕様](power.md)と[CIC・SFCリセット](cic-reset.md)、音声は[FPGA音声](../fpga/audio.md)を参照する。FPGAの同期STAとSFC実機の性能試験は[検証記録](../verification/README.md)を参照する。
