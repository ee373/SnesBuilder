# Rev.0.9 SDK・エミュレータ・USB連携

SFC側はPVSnesLibで65C816 HiROM/SlowROM最小サンプルを起動し、RISC-V側はVS Code＋AgRV SDK、FPGA側はPrepare LOGIC＋Supra Nativeを使う。SFCBuilder SDKは$5000通信の64アドレス窓、FIFO/IRQ、コプロセッサ演算、SRAM、メモリ所有権、NORローダをAPI化する。ares/bsnes/Snes9x等のエミュレータはROM4形式・容量ミラー・SRAM・通信・演算要求のゲームから見える挙動を再現する。

USB Full-SpeedではAG32をデバイス、PC/Raspberry Piをホストとし、画像・音声・操作・デバッグを双方向転送する。SFC側はFIFO/SRAMと65C816コードを介してVRAM/CGRAM/OAM/SPC700へ転送する。USBが接続されなくても通常ROMを起動可能とする。

## ゲーム固有RISC-VプログラムとFPGA演算器

SFCBuilderの共通ファームウェアはAG32内蔵Flashに常駐し、ゲームパッケージのRISC-Vコードは外部8MiB NORから内蔵SRAMへ展開して実行する。ゲーム用GCCリンクは内蔵SRAMを実行アドレスとし、共通Flash側のRAM領域と重複させない。共通ファームウェアのサービスは固定ABI/API経由で利用し、SFC側の65C816コードは既存の$5000通信窓とFIFO/IRQを通じてRISC-V側へ処理を要求する。

RISC-VがFPGA内の演算アクセラレータを使う場合は、内部AHBにメモリマップした入力・制御・状態・結果レジスタをMMIO経由で操作する。演算器のアドレスは生成トップで確定する。ゲームパッケージには65C816 ROM・RISC-V実行イメージ・リソース・セーブ定義の配置情報を持たせ、NOR物理容量8MiBの範囲内で格納する。
