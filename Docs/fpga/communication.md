# Rev.0.9 — SFCとAG32 RISC-Vの通信

SFC側の65C816はカートリッジの`$5000–$5FFF`窓を通じてAG32内蔵FPGAへ要求を送り、RISC-VはCPU側のAHB MMIO経由でレジスタとFIFOを操作する。通信レジスタはSFC A0～A5の64アドレス周期でミラーされ、MAP_CONFIGのbit7で有効化する。ROM互換のため無効化できる。

## SFCレジスタ

| SFCアドレス | オフセット | 名前 | 機能 |
|---|---|---|---|
| `$5000` | 00 | CPU_CONTROL | ゲーム固有RISC-Vアプリの停止要求 |
| `$5001` | 01 | COMMAND | SFC→RISC-Vコマンド |
| `$5002` | 02 | STATUS | 処理状態／アプリ停止完了bit3 |
| `$5003` | 03 | REPLY | RISC-V→SFC応答 |
| `$5004` | 04 | BUS_CONTROL | 外部MEM貸出 |
| `$5005` | 05 | TX_DATA | SFC→RISC-V FIFO |
| `$5006` | 06 | RX_DATA | RISC-V→SFC FIFO |
| `$5007` | 07 | FIFO_STATUS | TX件数bits2:0、RX件数bits6:4 |
| `$5008` | 08 | IRQ_CONTROL | 割り込みマスク |
| `$5009` | 09 | IRQ_STATUS | 割り込み状態とW1C ACK |
| `$500A` / `$500B` | 0A / 0B | LENGTH_L/H | 転送長 |
| `$500C` | 0C | ERROR | FIFOエラーとW1C消去 |

`$500D–$503F`は予約する。SFCアクセスは8 bit単位、CPUの対応MMIOは `0x60001000 + 4 × offset` の32 bit境界アクセスで、有効データは下位8 bitである。[本番FPGAのレジスタ定義](../../fpga/README.md)

## 停止制御とIRQ

`CPU_CONTROL` bit0の0はゲーム固有RISC-V処理の実行・再開、1は停止要求を意味する。`STATUS` bit3の`APP_STOPPED`は停止完了の通知であり、要求値とは区別する。停止するのはゲーム固有アプリで、共通ファームウェア、SFC通信、メモリ返却、電源断退避を継続する。アプリ停止に必要なRISC-Vファームウェアの実行境界と復帰処理は未完成のソフトウェア工程である。

FPGAは `local_int[0]` を通信・CPU貸出要求、`local_int[1]` をアプリ停止要求、`local_int[2]` をPOWER_FAIL通知に使用する。通信のIRQ_STATUSはbit0がコマンド保留、bit1が返信保留、bit2がRXデータあり、bit3がMEM返却通知である。CPUはbit0への1書込みでコマンドをACKし、SFCはbit1/3への1書込みで返信・返却通知をACKする。

## FIFOとREPLYの取り扱い

SFC→CPUのTX、CPU→SFCのRXは各4バイトFIFOである。SFCはTX_DATAに書き、RX_DATAを読み取る。CPUはTX_DATAから読み、RX_DATAへ書く。受信側がデータレジスタを読み取ると先頭データを取り出し、空の読出しは0となる。満杯時の書込みは破棄され、ERROR bit0（TX）またはbit1（RX）がセットされる。

REPLYは未ACKの返信を1件保持する。CPUはIRQ_STATUS bit1が0であることを確認してからREPLYへ書き込む。ACK前の上書き要求は元のREPLYを保持し、AHB ERRORを返す。旧ACKと新REPLYが同時に発生した場合は新しい値を格納する。共通ファームウェアでは [sfcbuilder_try_reply](../../fpga/include/sfcbuilder_reply.h) の戻り値に従い、未送信の値を保存して再試行する。

## ブート時の固定応答

内蔵Flashの共通ファームウェアは外部SRAM末尾8 KiBへBIOSを展開する。BOOT_CONTROLにより固定ブート応答を有効にすると、FPGAはSFC `$00:FFFC/FFFD`で`00/80`、`$00:8000–8003`で`5C/00/60/2F`を返し、65C816は`JML $2F6000`を実行する。固定応答はA6～A11をデコードせず、ブート終了時はRISC-VがBOOT_CONTROLのbit0を解除する。[ファームウェア](../firmware/boot.md)、[所有権](bus.md)
