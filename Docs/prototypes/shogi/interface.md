# Rev.0.9 将棋AI SFC/RISC-Vインターフェース

SFCの64アドレス通信窓を使用する。先頭`$5000 CPU_CONTROL`はゲーム固有RISC-V処理の停止（bit0=1）・実行/再開（bit0=0）を要求し、`$5002 STATUS` bit3で停止完了を確認する。停止中も共通ファームウェアによる通信、共有MEM調停、電源断時のセーブデータ退避を維持する。

レジスタの13オフセット、SFC側アドレス、CPU側32 bit MMIO、FIFO・IRQ・ACKの動作は[FPGA通信レジスタ仕様](../../fpga/communication.md)を正本とする。将棋AIはこの共通インターフェースを利用し、専用のハードウェアレジスタを追加しない。

`AI_INIT`、`AI_SET_POSITION`、`AI_MAKE_MOVE`、`AI_SEARCH`、`AI_STOP`、`AI_GET_BESTMOVE`、`AI_GET_SCORE`、`AI_SET_LEVEL`をゲーム固有の論理コマンドとして実装する。`AI_STOP`は探索を中止するコマンドであり、CPU_CONTROLによるアプリ実行停止とは異なる。CPU MEM使用中はWRAM待機と[bus.md](../../fpga/bus.md)の共有データバス調停に従う。レジスタ仕様の正本は[communication.md](../../fpga/communication.md)とする。

## AGM実装の接続点

RISC-V側でのSFC通信レジスタアクセスは `0x60001000 + 4 × offset` の32 bit MMIOを使用する。CPU SYSCLKは本番240 MHz、FPGA BUSCLKは80 MHz。FIFO・REPLY・IRQは既存[AG32 FPGA実装](../../../fpga/README.md)に含まれるが、上記の将棋固有コマンドと探索アプリはソフトウェアの実装対象である。
