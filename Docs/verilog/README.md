# HDL・論理検証資料

Rev0.8 / 2026-11-19。**現行の採用回路はAG256SL100 CPLDによるROM/SRAM高速バス制御とメモリ制御4信号の一元化と、PSoC UDBによる通信・FIFO・バス所有権制御の組合せ**である。正本は[../cpld.md](../cpld.md)、[../memory.md](../memory.md)、[../bus-udb.md](../bus-udb.md)、[../hardware.md](../hardware.md)とする。

## 現在の実装・検証状態

本ディレクトリにあるVerilogは、SFCBuilderの既存動作を検証するための履歴・参考資料である。**Rev0.8のAG256/8bitレベル変換構成に対応したRTLの合成、PSoC Creatorの合成・配置配線、FastROMのSTA、HDLシミュレーションはまだ完了していない。** 既存テスト結果をRev0.8の合格判定として扱わない。

Rev0.8の次の実装成果物は、CPLD ROM4形式/SRAM2形式/SPECIAL_SEL/OE制御のVerilog、PSoC UDB通信・FIFO・所有権制御の統合RTL、それぞれのテストベンチとAGM Supraフィッティング資源表である。

## 参考実装・履歴

| ファイル／ディレクトリ | 保存内容 |
|---|---|
| [integrated_rev07/](integrated_rev07/README.md) | 固定値ブート、メールボックス、双方向FIFO、所有権FSMなどのRev0.7動作モデルとPython検証記録 |
| rom_mirror_1m.v、check_1m.py、tb_rom_mirror_1m.v | 独立したミラーリング論理と検証 |
| rom_mirror_rev06.v、check_rom_mirror_rev06.py | ROM上位アドレス変換の独立モデル |
| sfcbuilder_bridge.v、tb_sfcbuilder_bridge.v、estimate_and_check.py | ブリッジと資源推定の参考実装 |
| verification.txt、verification.log、verification_package_1m.md | 各モデルの当時の検証出力 |

`integrated_rev07`にはROMアドレス変換、固定ブート応答、SFCとARMのバス所有権切替、FIFOレジスタモデルが含まれ、Pythonの参照モデル検証記録がある。Verilogコンパイルや実機CPLDへのフィッティングが実行されたものではない。Rev0.8では**ROMマップ・メモリ制御4出力・8T245 DIR/OE・LVC245A #1 /OEをAG256へ移管**し、CPU間通信とFIFO・ブート固定データをPSoC側へ残す。

## Rev0.8で実行するチェック

1. LoROM/ExLoROM/HiROM/ExHiROMのROM物理アドレスとヘッダ・ベクタ位置。
2. 128KiB SRAMの8KiB/32KiB窓とMEM A16–A19の変換。
3. $5000通信とBOOT_MODE特殊領域のROM/SRAM非選択と8T245データ側High-Z。
4. ARM所有中の$5000通信継続とSFC/ARM MEMバス出力の排他。
5. AG256の256 LUT、54/80 I/Oへの適合とFastROM 120nsのSTA。
