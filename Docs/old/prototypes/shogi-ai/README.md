# Rev.0.9 — AGM RISC-V将棋AI実証

対象はAG32VF407VGT6の **RV32IMAFC（本番SYSCLK 240 MHz）**。SFC側65C816で盤面表示、入力、ゲーム進行を行い、RISC-V上のゲーム固有アプリが合法手生成、探索、評価を担当する。FPGAとの通信には `$5001 COMMAND`、`$5005 TX_DATA`、`$5006 RX_DATA`、IRQを使用する。`$5000 CPU_CONTROL`はアプリ全体の停止要求であり、探索だけを中断する`AI_STOP`とは区別する。

## メモリ割当てと探索

外部8 MiB NORにSFC用ROM、圧縮評価関数と必要なリソースを保存する。内蔵SRAM 128 KiBでは探索スタック・局面表現・NNUE Accumulator・ゲーム固有RISC-Vコードと共通ファームウェアの作業域を分ける。外部SRAM 128 KiBには置換表やセーブ・共有データを配置する計画で、SFCと共用する8 bit MEMバスのアクセス制御が必要である。内蔵Flash上のJet/cmixer共通ライブラリは将棋AIでは呼び出さない。

第一段階は整数評価関数と反復深化・αβ探索・手の順序付け・静止探索・置換表をCPU単独で実装する。次にPCで学習・圧縮したNNUEを外部NORから必要に応じて読み込み、整数の差分Accumulatorを使用して比較する。最適化の評価指標は固定時間当たりのNPS、到達深さ、着手品質、対局成績とする。製品実行クロック240 MHzを使用して測定し、CPUの最大仕様248 MHzを実測値として扱わない。

## 統合と段階

最初にSFC↔FPGA↔RISC-V間で固定の合法手を返信し、その後USB経由のPC思考エンジン連携、RISC-V単独探索、NNUEと圧縮重み展開を進める。FPGAのINT16×4 MACは[ロードマップ](../../roadmap.md)の追加検討であり、現行RTLに実装されていない。SFCゲーム素材の再利用・配布条件は別途確認する。

[コマンド仕様](integration.md)・[NNUEメモリ](nnue-memory.md)・[マイルストーン](milestones.md)・[共通通信](../../communication.md)
