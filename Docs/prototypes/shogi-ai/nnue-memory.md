# Rev.0.9 NNUE格納・演算計画

AG32 RV32IMAFC最大248MHz、CPU内蔵SRAM128KiB、外部NOR8MiB、外部SRAM128KiBを使用する。PCで学習・重み圧縮し、実機では整数演算と差分更新・部分復号を実施する。CPU SRAMに探索スタック/Accumulator、NORにゲームROM/圧縮NNUE、外部SRAMに置換表/セーブ、microSDに外部資産を配置する。実ファイルの圧縮率で容量を確定し、SFCとのMEM共有・WRAM待機を含めてメモリ帯域を測定する。
