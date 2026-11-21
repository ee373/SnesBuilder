# Rev.0.9 — AG32 FPGAのROM互換性

SFC ROMのアドレス変換はRISC-VソフトウェアではなくFPGAが処理する。現行の [sfcbuilder.v](../../fpga/rtl/sfcbuilder.v) はLoROM、HiROM、ExLoROM、ExHiROMとROMサイズマスク、SRAMおよび起動BIOSのデコードを実装する。合成とRTLシミュレーションで確認した範囲と、個々のSFCゲームの実機互換性は区別する。

## ROM形式と容量

| ROM_SIZE | 容量 | 物理アドレスの処理 |
|---|---|---|
| 0 | 128 KiB | A17～A22を0 |
| 1 | 256 KiB | A18～A22を0 |
| 2 | 512 KiB | A19～A22を0 |
| 3 | 1 MiB | A20～A22を0 |
| 4 | 2 MiB | A21～A22を0 |
| 5 | 4 MiB | A22を0 |
| 6 | 8 MiB | マスクなし |

`MAP_CONFIG`（CPU側`0x60000000`）のbit0はSFCバス有効、bit1はLoROM系選択（0=HiROM系）、bit2はEx形式、bits5:3は上表のROM_SIZE、bit6はセーブSRAM窓、bit7はSFC通信窓を指定する。**ROM_SIZE=7も現行RTLでは6と同じ8 MiBとして処理されるが、設定値は0～6を使用する。** 非2の冪乗のROMはローダが元のROMのミラー規則に沿ってNORへ事前展開する。ROM容量マスクはSFC側ROM読出しに適用し、RISC-V側の物理NOR書込み・読出しには適用しない。

HiROMの基本アドレスはMEM A0～A21をSFC A0～A21に対応させる。LoROMではMEM A0～A14をSFC A0～A14へ、MEM A15～A21をSFC A16～A22へ対応させ、Ex領域はMEM A22で選択する。WRAM/IO/特別領域とSRAMの優先デコードを行う。起動時は物理SRAM末尾8 KiBのBIOS窓を有効化し、BIOS終了後は解除できる。セーブ永続化の対象は物理SRAM先頭120 KiBである。

## 互換性確認

初期検証はPVSnesLibのHiROM/SlowROMを対象とし、LoROM・Ex形式、全7段階のROM_SIZE、非2冪ROMのミラー、SRAMの優先順位、割り込み・リセットベクタと通信窓競合を拡張する。SlowROM 200 ns／FastROM 120 nsの実機タイミングは未測定。[マッピングの物理配線](../hardware/memory-devices.md)、[FPGA検証](../verification/README.md)、[SFC通信](communication.md)
