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

## AG32のピン割当て・ストラップ・IP接続

AG32物理100ピンの信号名、入出力種別、固定電源・NC端子は[pinout.csv](pinout.csv)を正本とする。AG32の使用対象は、MEMアドレス23本、共通MEMデータ8本、SFC専用アドレス18本と制御端子、レベル変換ICの/OE、microSD/SPI NOR、USB、UART0、SWD、左右DSM音声、POWER_FAILである。FPGAのピン使用と生成トップとの突合は[fpga/top.ve](../../fpga/top.ve)を基準とする。

BOOT0/BOOT1は通常Lowで使用し、UARTによる復旧時には起動ストラップを切り替える。JTAG兼用のGPIOはSWDを確保したうえで、外部MEMとUSB VBUS検出に割り当てる。実装上のGPIO予備は1本とし、電源と固定機能を含む100ピン表の値を別文書へ複製しない。

## AG32内蔵FPGAとRISC-Vの接続

内蔵FPGAはROMマッピング、共通NOR/SRAM制御、CPU側AHBブリッジ、SFC通信レジスタ、FIFO、起動固定応答、バス調停を担当し、RISC-VはUSB・microSD・ローダ・ゲーム固有演算・音声生成を担当する。CPU→FPGAの32 bit `mem_ahb_*`、`local_int[3:0]`とクロック・リセットはPrepare LOGICの生成トップへ接続する。現行RTLの`slave_ahb_*`は使用せず、固定値にしている。

外部MEM A0～A5・A12～A22の17本はFPGA側のアドレスMUXで生成し、A6～A11の6本はU1/U6の出力許可を排他制御する。MEM D0～D7はSFC、NOR/SRAM、AG32で共通であり、CPU所有中に別のSFC用データバスが存在するわけではない。所有権FSM、ストローブ抑止、WRAM側待機、NOR BUSY、MMIOアドレス・AHB ERRORの詳細は[FPGAバス](../fpga/bus.md)を、SFCの通信窓と13レジスタは[FPGA通信](../fpga/communication.md)を正本とする。起動時の固定応答とSFC BIOSは[ブート仕様](../firmware/boot.md)を参照する。

## 関連仕様

外部NOR/SRAMの部品側ピンは[メモリ配線](memory-devices.md)、ROM形式は[FPGAマッピング](../fpga/rom-mapping.md)、MEM所有権とMMIOは[FPGAバス](../fpga/bus.md)、電源とCICは[電源仕様](power.md)と[CIC・SFCリセット](cic-reset.md)、音声は[FPGA音声](../fpga/audio.md)を参照する。FPGAの同期STAとSFC実機の性能試験は[検証記録](../verification/README.md)を参照する。
