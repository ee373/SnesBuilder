# SFCBuilder

SFC/SNES向け **AGM AG32VF407VGT6（RISC-V＋FPGA）** 拡張開発カートリッジ。現行設計は **Rev.0.9**。CPU 240 MHz、FPGA BUSCLK・FIR 80 MHz、DSM 8 MHzを本番設定とし、8 MiBパラレルNOR、128 KiB外部SRAM、256 KiBセーブ用SPI NOR、USB Full-Speed、microSD、追加ステレオ1 bit ΔΣ音声を使用する。

現行AG32向けのFPGA RTLは合成・配置配線・STAとテストベンチ検証を実施済み。SFC実機のROMタイミング、基板・電源・アナログ音声と、ゲーム固有RISC-Vファームウェア・Jet/cmixer・USB映像の統合は継続検証項目とする。

[現行設計仕様](Docs/README.md) · [FPGAプロジェクト](fpga/README.md) · [検証記録](Docs/verification/README.md) · [実装ロードマップ](Docs/roadmap.md)
