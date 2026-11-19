# Rev.0.9 RISC-VファームウェアとSFC BIOS

AG32のRISC-V CPUはゲームローダ、NOR消去/書込み、セーブ同期、USB Full-Speed、microSD SPI、演算コプロセッサ、左右DAC音声、FPGA制御を担当する。CPU内蔵SRAMは128KiB。内蔵Flashの利用可能容量は調達型番のメーカー表とリンクスクリプトで最終確定する。外部MEMアクセスはFPGAのAHBメモリコントローラを利用しGPIOのビット単位駆動を行わない。

起動時はCIC/電源とOE安全状態を確保し、CPUがMEM所有権を取得して外部SRAM末尾8KiBにBIOSを展開し、ROM形式・容量・通信を設定してSFC /RESETを解除する。

電源投入後RISC-Vが外部SRAM物理0x1E000～0x1FFFFへ8KiBのSFC用BIOSを展開し、ROM形式・MEM所有権設定後にSFC /RESETを解除する。FPGAは$00:FFFC/FFFDへ00/80、$00:8000～8003へ5C/00/60/2Fの固定6バイトを返し、SFCが`JML $2F6000`を実行する。通信窓は$00–$3F/$80–$BF:$5000–$5FFF、SFC A0～A5の64アドレス周期とし、有効化レジスタでゲームROMとの競合を避ける。初期12レジスタは00 COMMAND、01 STATUS、02 REPLY、03 BUS_CONTROL、04 TX_DATA、05 RX_DATA、06 FIFO_STATUS、07 IRQ_CONTROL、08 IRQ_STATUS、09/0A LENGTH、0B ERRORとし、0C–3Fを予約する。双方向FIFOは初期各4バイトを想定する。

ゲームパッケージは65C816 ROM、RISC-V実行コード、リソース、セーブ定義を組み合わせる。NORは7段階容量ミラーと非2冪展開を扱い、初期テストはPVSnesLib HiROM/SlowROMで行う。
