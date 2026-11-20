# Rev.0.9 正規開発環境・ライセンス・書込み

RISC-V側はVS Code＋AgRV SDK、FPGA側はPrepare LOGICによるAG32 CPU/FPGA接続トップの自動生成後、**AGM Supra Native**でVerilog合成・配置配線・BIN生成を実行する。NativeモードはAGMのYosys系合成エンジンを使用しQuartusを必要としない。開発環境はWindows10/11のVMに配置し、Icarus Verilog/Verilatorによる独立シミュレーションも利用する。

Supraはメーカー配布パッケージのライセンス条件に従う。AGaMEMnon（MIT）は技術的参考とするがLQFP100と広いAHB・物理GPIOの実証が限定されるため標準フローに採用しない。書込み・デバッグにはAGM DAP LINK/CMSIS-DAPを第一候補とし、AG32 SWDIO72、SWCLK76、NRST14、3.3V VTrefとGNDを接続する。UART0 TX/RX68/69、BOOT0=94、BOOT1=37をROMブート復旧用に引き出す。

検証対象は自動生成トップのAHB・IRQ・DMA、MEM D0–D7の双方向出力OE、外付けU1/U6排他OE、SFC非同期入力→出力最大遅延の取得、およびFastROM120nsである。単純なSetup/HoldレポートをSFC非同期バス全体の保証と解釈しない。

参考：[AG32公式](https://www.ag32mcu.com/aum-product/products_mcu_ag32vf407_100/)・[Native実機開発例](https://blog.csdn.net/Naisu_kun/article/details/166950248)・[AGaMEMnon](https://github.com/bbenchoff/AGaMEMnon)。

Rev.0.9のアドレスマッピング初版、ピン制約、再ビルド手順は [FPGAプロジェクト](../fpga/README.md) を参照。
