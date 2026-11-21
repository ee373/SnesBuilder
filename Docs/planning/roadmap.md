# Rev.0.9 AG32 実装・実機検証ロードマップ

対象はAG32VF407VGT6、CPU 240 MHz／FPGA BUSCLK・FIR 80 MHz／DSM 8 MHzの現行本番構成とする。「RTL・STA完了」と「実機・製品動作確認」は異なる工程として扱う。[本番FPGA記録](../verification/README.md) と [FPGAプロジェクト](../../fpga/README.md) を参照する。

## FPGAと開発基盤

- [x] AG32向け `top.ve`、ピン定義、Supra Nativeプロジェクト、再ビルド手順を用意。
- [x] ROM4デコード、7段階ROM容量マスク、非同期ROM応答、SFC起動固定応答、SRAM BIOS窓をRTLへ実装。
- [x] CPU→FPGA AHBの32 bitアクセス、8 bit NOR/SRAM展開、HREADYOUT・HRESP、MMIO制御レジスタ、双方向FIFO、IRQをRTLへ実装。
- [x] U1/U6/U5の出力許可、MEM所有権・NOR BUSY、WRAM待機を前提とした返却IRQ、POWER_FAIL保持、SPI選択デコーダをRTLへ実装。
- [x] 64 kHz・16 bit PCM FIFO、80 MHzポリフェーズFIR、8 MHz・3次DSMを統合し、RTLテストと本番配置配線・STAを完了。
- [x] CPU 240 MHz・FPGA 80 MHz・DSM 8 MHzの本番配置配線で同期タイミング制約に合格（最悪セットアップ+0.220 ns、ホールド+0.080 ns）。
- [ ] AG32内蔵Flashの起動ファームウェア、外部NOR書込み、SRAM BIOS展開、ゲーム固有RISC-VのSRAM実行と共通ABIを統合。
- [ ] FPGAの実機ピン・双方向OE・AHB・FIFO・NOR/SRAMを基板上で測定し、SlowROM 200 ns／FastROM 120 nsを確認。
- [ ] 電源・CIC・SFC /RESET、電源断中のCPU／FPGA／SPIデコーダ動作、セーブ用NORの二重バンクを検証。
- [ ] RISC-Vソフトウェアの停止／再開と、停止中のSFC通信・電源断退避・復帰を検証。

## ソフトウェア・アプリケーション

- [ ] PVSnesLibのHiROM/SlowROMサンプル、LoROM/Ex形式、SRAMミラー、ROM容量境界の実機互換性を検証。
- [ ] SFCBuilder SDKの通信・バス貸出・音声・ローダAPIとエミュレータの拡張機能を実装。
- [ ] 共通FlashのJetとcmixerを移植し、PCM MMIOを使用する16音ミキシングとSFC標準8音の併用を検証。
- [ ] 約22 kHzの外部アナログLPFを含む音声端子の周波数特性・SNR/SINAD・THD+Nを測定。
- [ ] 152×104（128画素8bpp＋24画素動的RGB555）の3D/USB表示で、DMA/HDMA 8チャネル共用、上下8走査線ずつのブランキング、偶奇52＋52ラインの独立性と表示遅延を検証。
- [ ] Jet 3D起動ロゴ、cmixerのジングル、将棋AI探索・NNUEとSFC通信の統合試験を実施。

## 追加検討：INT16×4ドット積MAC

CPU側AHBへMMIO接続する符号付きINT16×4ドット積型の追加演算器を将来案とする。`ACC ← ACC + Σ(A[i]×B[i])` を想定し、16×16の積4個の和は少なくとも34 bit幅、累積は64 bitを候補とする。乗算器を1／2／4基とした構成についてLUT、FF、BRAM、タイミング、転送負荷込みの処理時間を比較する。現行の1,934／2,112スライス使用率を踏まえ、基本のROM/通信/音声機能を維持できる場合にのみ採否を判断する。現行RTLには未実装。
