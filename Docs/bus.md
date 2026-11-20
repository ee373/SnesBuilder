# Rev.0.9 FPGA・AHB・MEM所有権

FPGAはROMマッピング、メモリ制御、AHBコントローラ、通信レジスタ、FIFO、起動固定応答、バス調停を担当する。カートリッジからSFC本体への映像転送でも共通MEM所有権調停を用い、画像本体は共有SRAM、通知は`$5001 COMMAND`等の通信レジスタ/FIFO/IRQを利用する。`$5000 CPU_CONTROL`はゲーム固有RISC-V処理の停止要求、`$5004 BUS_CONTROL`はMEM所有権制御として独立させる。3DデモとUSB映像モードの表示経路は[SDK・USB連携](sdk-emulator.md#カートリッジからsfc本体への映像転送)を参照する。RISC-VはUSB・microSD・ローダ・演算・音声を担当する。CPU→FPGA内部AHB `mem_ahb_*`、FPGA→CPU側`slave_ahb_*`、`ext_dma_*`、`local_int[3:0]`、sys_clock/bus_clock/resetnをPrepare LOGICの自動生成トップで接続する。外部MEM A0～A5・A12～A22の17本はFPGAのSFC/CPUアドレスMUX出力、A6～A11はU1/U6の所有権切替で駆動する。

映像転送では**152×104（128px通常BG1 8bpp＋24px動的RGB555）**の共通表示経路を採用し、65C816が共有SRAMを転送元にVRAM DMA・CGRAM/BG1VOFS HDMAを実行する。上下各8走査線の追加強制ブランキングを設けるが、DMA/HDMAの8チャネル共用、HDMAのフレーム先頭初期化、共有MEMの単一所有権を考慮し、表示期間のHDMA読出しとRISC-VによるSRAMへの書込みは所有権FSMで競合させない。実転送時刻と完成バッファの切替を[3Dデモ](prototypes/3d-demo/README.md)の検証条件に従って確認する。

CPUのAHBメモリ窓候補は制御0x60000000、FIFO0x60001000、NOR8MiB=0x61000000、SRAM128KiB=0x62000000であり、AG32の実際の外部AHB領域と生成トップのデコードに照合する。8bit MEMの16/32bitアクセスを複数バイトサイクルに変換し、HREADYOUTを使ってCPU側を待機させる。

**MEM D0～D7はSFCとNOR/SRAMとAG32で共通のため、CPU所有中にも独立したSFC通信データバスが存在するわけではない。** SFCの$5000特殊応答前にCPU側のメモリストローブを終了・停止し、NOR/SRAM/U5/AG32の出力方向を切替する。SFCのアクセス時間を任意に延長できないため、短いMEMサービス枠、NORプログラム中のBUSY、WRAM側待機プロトコルを含むアービタを実装する。所有権FSMはISOLATE→QUIET→CONFIGURE→GUARD→OWNER、切替時はU1/U6/U5を一時無効化してMEM制御を非選択とする。

CPUへの貸出時間はソフトウェアが管理する。貸出中は65C816をWRAMで待機させ、カートリッジへのCPU・DMA・HDMAアクセスは返却後に再開する。FPGAはCPU所有中にSFC側のU1/U5を無効にし、返却要求後に進行中の転送とNOR BUSYの終了を待つ。貸出時間による強制返却は行わない。

MEM制御4本はAG32 PIN61–64、U1/U6/U5の出力許可制御はPIN65–67、外部MEMデータ8本はPIN78–85を使用する。FPGAはCPUメモリ書込み、BIOS固定応答、SFC通信レジスタ読出しでのみMEMデータ線を駆動する。SFC A6–A11はU1を通り、CPU側のA6–A11はAG32 PIN55–60からU6を通る。PIN55–60はCPU所有時だけ駆動する。所有権切替時はU1/U6の両出力とAG32 PIN55–60をHi-Zにする。

SlowROM200ns以内を必須、FastROM120ns以内を設計目標とする。SFC→U1→NOR、SFC→U2/U3/U4→FPGA→NOR、SFC /ROMSEL→FPGA→NOR /CE、NOR→U5→SFCの各経路を独立して評価する。Supra Nativeの非同期I/Oタイミング制約・レポートを検証し実機測定を行う。
