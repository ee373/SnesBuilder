# Rev.0.9 将棋AI SFC/RISC-Vインターフェース

SFCの64アドレス通信窓を使用する。先頭`$5000 CPU_CONTROL`はゲーム固有RISC-V処理の停止（bit0=1）・実行/再開（bit0=0）を要求し、`$5002 STATUS` bit3で停止完了を確認する。停止中も共通ファームウェアによる通信、共有MEM調停、電源断時のセーブデータ退避を維持する。

| SFCアドレス | レジスタ |
|---|---|
| `$5000` | CPU_CONTROL |
| `$5001` | COMMAND |
| `$5002` | STATUS |
| `$5003` | REPLY |
| `$5004` | BUS_CONTROL |
| `$5005` | TX_DATA |
| `$5006` | RX_DATA |
| `$5007` | FIFO_STATUS |
| `$5008` | IRQ_CONTROL |
| `$5009` | IRQ_STATUS |
| `$500A/$500B` | LENGTH_L/H |
| `$500C` | ERROR |

`AI_INIT`、`AI_SET_POSITION`、`AI_MAKE_MOVE`、`AI_SEARCH`、`AI_STOP`、`AI_GET_BESTMOVE`、`AI_GET_SCORE`、`AI_SET_LEVEL`をゲーム固有の論理コマンドとして実装する。`AI_STOP`は探索を中止するコマンドであり、CPU_CONTROLによるアプリ実行停止とは異なる。CPU MEM使用中はWRAM待機と[bus.md](../../bus.md)の共有データバス調停に従う。レジスタ仕様の正本は[communication.md](../../communication.md)とする。
