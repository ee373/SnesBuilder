# Rev.0.9 将棋AI実証

65C816側の表示・操作・進行を使用し、思考エンジンをAG32VF407VGT6のRISC-Vへ移す。FPGAの$5000通信、双方向FIFO・IRQとCPU演算を組み合わせる。NOR8MiBにはSFC側ROM・圧縮評価関数、CPU SRAM128KiBにはAccumulator・探索、外部SRAM128KiBには補助探索・セーブを配置する。USB経由でPC将棋エンジンを利用する段階も設ける。既存ゲームの解析・配布条件を確認する。
