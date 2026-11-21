# AGM AG32VF407VGT6 FPGA開発・ビルド

Rev.0.9の正規開発ターゲットは **AG32VF407VGT6（AGRV2KL100）**。RISC-Vのソフトウェア開発にはAgRV SDK、ハードIP接続トップにはPrepare LOGIC、FPGA合成・配置配線にはAGM Supra Nativeを使用する。合成にはAGMのNativeフローを使用し、Quartusは使用しない。

## 構成とツール

本番構成はRISC-V 240 MHz、BUSCLK・音声FIR 80 MHz、外部8 MHz水晶由来のDSM、USB用PLL 60 MHzである。`fpga/audio-clocks.ve` はPrepare LOGICへ96 MHzのFIRクロックを要求する入力断片だが、**本番の `build.ps1` は生成トップ内の独立FIRクロックをBUSCLK 80 MHzの共用配線へ置換する**。したがって最終RTLのFIR動作は96 MHzではなく80 MHzである。AG32のピン接続は [pinout.csv](pinout.csv)、FPGAトップは [../fpga/top.ve](../fpga/top.ve)、Verilogは [../fpga/rtl](../fpga/rtl/) を参照する。Supra Nativeの採用版は2024.08.b0で、Nativeモードの合成・配置配線を使用する。開発はWindows 10/11環境（VMを含む）を想定する。

```powershell
cd fpga
./build.ps1
```

ビルドには親ディレクトリの `AGM/AgRV_pio` と `AGM/pio-env` を使用する構成である。スクリプトは合成結果と制約の入力ハッシュを検査し、条件が一致する場合は [verified-route](../fpga/verified-route/) の合格済み配置を再解析して本番イメージを生成する。新規配置配線時は適切な `-Seed`、既存合格配置の持込み時は `-VerifiedRoute` を指定する。構成バイナリとSTAレポートの通常の生成場所は `fpga/rtl/top.bin`、`fpga/rtl/alta_db/` であり、Gitに含まれることを前提としない。

## バス・同期・書込み

AG32内蔵CPUとFPGAの接続は32 bit `mem_ahb_*` を使用する。`slave_ahb_*` は本番RTLで無効化し、割り込みは `local_int[0:2]` を使用する。AHBは240／80 MHz間で段階化したハンドシェイクと登録済み読出しデータを利用する。[本番アドレス・AHB仕様](verification/ahb-interface.md) を参照する。

電源断の退避中は、CPUのみ低速動作へ変更する場合でもFPGAの80 MHz BUSCLKを維持する。AgRV SDKの `SYS_SwitchHSIClock()` はPLLを停止するため、FPGAメモリ調停が必要な退避処理で使用しない。

書込み・デバッグはAGM DAP LINK/CMSIS-DAPを基本とし、AG32 SWDIO（PIN72）、SWCLK（PIN76）、NRST（PIN14）、VTrefとGNDを使用する。UART0 TX/RX（PIN68/69）およびBOOT0/1（PIN94/37）は復旧用に確保する。単体RTLテストはIcarus Verilog/Verilatorでも実行できる。

## 検証範囲

本番RTLの合成と配置配線後STAは確認されている。外部NORの70 ns、SFC側の入力バッファ、FPGAの非同期遅延、U5、PCBと65C816の要求時間を組み合わせた実機アクセス検証は別工程である。[合成結果](verification/README.md) と [SFCバス](bus.md) を参照する。

参考：[AG32公式](https://www.ag32mcu.com/aum-product/products_mcu_ag32vf407_100/)・[Supra Native実機開発例](https://blog.csdn.net/Naisu_kun/article/details/166950248)。
