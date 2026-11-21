# Rev.0.9 — CIC・SFCリセット・割り込み配線

## SFC制御・CIC

U1/U6の/OEは3.3Vプルアップ、U5の/OEは安全側プルアップ、NOR/SRAM制御は非選択プルアップとする。SFC /RESET端子26は5V⇄3.3V双方向オープンドレイン変換回路でAG32 PIN7へ、SFC /IRQ端子18はAG32 PIN26のLow駆動回路へ接続する。AG32 NRST PIN14とSFC /RESETは独立する。CICはPIC12F629-I/SNとSuperCIC Keyを採用してSFC端子24/25/55/56へ接続する。ICSP・SWD・UART0・BOOT0/1をテストパッドへ引き出し、AG32＋FPGAの高負荷時とNOR書込み時のMCP1825S最大出力電流・温度を測定する。

SFCエッジ端子の番号は[インターフェース](interface.md)、AG32の100ピン割当ては[ピン表](pinout.csv)、U1/U6/U5の方向制御は[レベル変換](level-shifters.md)を参照する。
