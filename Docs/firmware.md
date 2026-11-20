# Rev.0.9 RISC-VファームウェアとSFC BIOS

AG32のRISC-V CPUはゲームローダ、NOR消去/書込み、SPI NORへのセーブ退避と復元、USB Full-Speed、microSD SPI、演算コプロセッサ、左右DAC音声、FPGA制御を担当する。CPU内蔵SRAMは128KiB。内蔵Flashの利用可能容量は調達型番のメーカー表とリンクスクリプトで最終確定する。外部MEMアクセスはFPGAのAHBメモリコントローラを利用しGPIOのビット単位駆動を行わない。

起動時はCIC/電源とOE安全状態を確保し、CPUがMEM所有権を取得する。SPI NORの128KiB×2バンクからCRC・世代番号・保存完了マーカーが正常な最新世代を選び、外部SRAMの物理先頭120KiBへ復元してから、末尾8KiBにSFC用BIOSを展開する。通常給電中に非採用側のSPI NORバンクを消去・準備し、ROM形式・容量・通信を設定した後、SFC /RESETを解除する。

電源投入後RISC-Vが外部SRAM物理0x1E000～0x1FFFFへ8KiBのSFC用BIOSを展開し、ROM形式・MEM所有権設定後にSFC /RESETを解除する。FPGAは$00:FFFC/FFFDへ00/80、$00:8000～8003へ5C/00/60/2Fの固定6バイトを返し、SFCが`JML $2F6000`を実行する。通信窓は$00–$3F/$80–$BF:$5000–$5FFF、SFC A0～A5の64アドレス周期とし、有効化レジスタでゲームROMとの競合を避ける。初期12レジスタは00 COMMAND、01 STATUS、02 REPLY、03 BUS_CONTROL、04 TX_DATA、05 RX_DATA、06 FIFO_STATUS、07 IRQ_CONTROL、08 IRQ_STATUS、09/0A LENGTH、0B ERRORとし、0C–3Fを予約する。双方向FIFOは初期各4バイトを想定する。

ゲームパッケージは65C816 ROM、RISC-V実行コード、リソース、セーブ定義を組み合わせる。NORは7段階容量ミラーと非2冪展開を扱い、初期テストはPVSnesLib HiROM/SlowROMで行う。

## 電源断時のSRAMバックアップ

AG32 PIN24のアクティブHigh `POWER_FAIL`（SFC生5VをLMV331で監視）を検出したら、SFCへのデータバス出力を無効化し、MEM所有権をCPUへ移行する。AG32は低クロックRunで動作を継続し、USB・音声・microSD等の不要な処理を止め、FPGA/AHB・SRAM・SPI NORの必要な動作を維持する。SRAM物理0x00000～0x1DFFFの120KiBを専用SPI NORの消去済みバンクへページ書込みし、Flashの内部書込み完了待機、CRC・世代番号記録、最後の保存完了マーカー確定まで終了させる。前回の有効バンクは書込み途中に変更しない。

内蔵FlashやmicroSDへ電源断セーブデータを書き込む処理は設けない。microSDは通常のゲームデータ入出力に引き続き使用する。SPI NORとmicroSDは同一SPI信号線を共有し、それぞれ独立した/CSを持つ。バックアップ中はmicroSDの/CSを非選択にする。

HiCAP充電完了の検出と起動待ち制御は設けない。初回起動・長期未使用時の充電時間は取扱説明書で案内する。実装時は電源断割り込みとバス所有権の順序、復帰時の状態遷移、最悪書込み時間・HiCAP保持時間、CRCと完了マーカーの電源断耐性を検証する。SFC側無給電時のGPIO/レベル変換ICの挙動も確認する。
