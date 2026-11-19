# Rev.0.9 SDK・エミュレータ・USB連携

SFC側はPVSnesLibで65C816 HiROM/SlowROM最小サンプルを起動し、RISC-V側はVS Code＋AgRV SDK、FPGA側はPrepare LOGIC＋Supra Nativeを使う。SFCBuilder SDKは$5000通信の64アドレス窓、FIFO/IRQ、コプロセッサ演算、SRAM、メモリ所有権、NORローダをAPI化する。ares/bsnes/Snes9x等のエミュレータはROM4形式・容量ミラー・SRAM・通信・演算要求のゲームから見える挙動を再現する。

USB Full-SpeedではAG32をデバイス、PC/Raspberry Piをホストとし、画像・音声・操作・デバッグを双方向転送する。SFC側はFIFO/SRAMと65C816コードを介してVRAM/CGRAM/OAM/SPC700へ転送する。USBが接続されなくても通常ROMを起動可能とする。
