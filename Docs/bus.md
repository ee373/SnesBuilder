# Rev.0.9 FPGA・AHB・MEM所有権

FPGAはROMマッピング、メモリ制御、AHBコントローラ、通信レジスタ、FIFO、起動固定応答、バス調停を担当する。カートリッジからSFC本体への映像転送でも共通MEM所有権調停を用い、画像本体は共有SRAM、通知は通信レジスタ/FIFO/IRQを利用する。3DデモとUSB映像モードの表示経路は[SDK・USB連携](sdk-emulator.md#カートリッジからsfc本体への映像転送)を参照する。RISC-VはUSB・microSD・ローダ・演算・音声を担当する。CPU→FPGA内部AHB `mem_ahb_*`、FPGA→CPU側`slave_ahb_*`、`ext_dma_*`、`local_int[3:0]`、sys_clock/bus_clock/resetnをPrepare LOGICの自動生成トップで接続する。外部MEM A0～A5・A12～A22の17本はFPGAのSFC/CPUアドレスMUX出力、A6～A11はU1/U6の所有権切替で駆動する。

CPUのAHBメモリ窓候補は制御0x60000000、FIFO0x60001000、NOR8MiB=0x61000000、SRAM128KiB=0x62000000であり、AG32の実際の外部AHB領域と生成トップのデコードに照合する。8bit MEMの16/32bitアクセスを複数バイトサイクルに変換し、HREADYOUTを使ってCPU側を待機させる。

**MEM D0～D7はSFCとNOR/SRAMとAG32で共通のため、CPU所有中にも独立したSFC通信データバスが存在するわけではない。** SFCの$5000特殊応答前にCPU側のメモリストローブを終了・停止し、NOR/SRAM/U5/AG32の出力方向を切替する。SFCのアクセス時間を任意に延長できないため、短いMEMサービス枠、NORプログラム中のBUSY、WRAM側待機プロトコルを含むアービタを実装する。所有権FSMはISOLATE→QUIET→CONFIGURE→GUARD→OWNER、切替時はU1/U6/U5を一時無効化してMEM制御を非選択とする。

MEM制御4本はAG32 PIN61–64、U1/U6/U5の出力許可制御はPIN65–67、外部MEMデータ8本はPIN78–85を使用する。SFC A6–A11はAG32で入力しない。FPGAはROMアドレスMUX17本とU1/U6外部バッファによってMEMアドレスを構成する。

SlowROM200ns以内を必須、FastROM120ns以内を設計目標とする。SFC→U1→NOR、SFC→U2/U3/U4→FPGA→NOR、SFC /ROMSEL→FPGA→NOR /CE、NOR→U5→SFCの各経路を独立して評価する。Supra Nativeの非同期I/Oタイミング制約・レポートを検証し実機測定を行う。

## 映像転送における共有MEMとDMA/HDMAの排他

[3Dデモ・USB映像の共通方式](sdk-emulator.md#カートリッジからsfc本体への映像転送)では、1フィールドの通常側VRAM用8bppタイル全更新7,168Bと、動的CGRAM用RGB555色情報2,496Bを共有SRAM経由で渡す。65C816は上下各8走査線の強制ブランキングおよび通常V-Blankの利用可能な期間にVRAM DMAを行い、中央208走査線ではHDMA全8チャネルをCGRAMとBG1VOFSに使用する。通常DMAとHDMAは同じ8チャネルを使用するため、DMA時のHDMA無効化・初期化・再開、SRAM所有権とバッファ完成通知を同期させる。

FPGAはSFCのDMA/HDMA用SRAM読み出しに必要なMEMサービス枠を確保し、RISC-Vが次フィールドの素材を生成していても、表示中のSFCアクセスを妨げないように調停する。映像の完成前にDMAを開始せず、HDMAが参照するデータをRISC-Vが更新しない。上側ブランキングのDMA利用方法、実効転送時間、可視期間のCGRAM書込みタイミングは[3Dデモの検証条件](prototypes/3d-demo/README.md#6-検証手順と合格条件)に従い、実装・実機検証で確定する。
