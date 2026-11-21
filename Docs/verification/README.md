# Rev.0.9 — AGM FPGA本番ビルドの検証記録

2026-11-20時点の対象は **AG32VF407VGT6（AGRV2KL100）**。合成・配置配線・STAとRTLシミュレーションによる確認を記載する。SFC実機、基板配線、アナログ音声の合格判定はここに含めない。詳細なAHB信号と測定値は [ahb-interface.md](ahb.md) を正本とする。

## 現行ビルドの条件

| 項目 | 実装・確認値 |
|---|---|
| RISC-V SYSCLK | 240 MHz |
| FPGA BUSCLK／音声FIR | 80 MHz |
| 3次DSM | 水晶由来8 MHz |
| USB PLL出力 | 60 MHz |
| 合成・配置配線 | AGM Supra Native 2024.08.b0、seed 1234 |
| 本番RTL | [sfcbuilder.v](../../fpga/rtl/sfcbuilder.v)、[sfcbuilder_audio.v](../../fpga/rtl/sfcbuilder_audio.v) |
| CPU・FPGA接続 | [top.ve](../../fpga/top.ve) |
| 制約 | [timing.sdc](../../fpga/timing.sdc) |
| 再ビルド | [build.ps1](../../fpga/build.ps1) |

## 本番配置配線結果

CPU 240 MHz／BUSCLK・FIR 80 MHz／DSM 8 MHzの合成、配置配線、四条件のSTAを実施した。**セットアップ・ホールド余裕、LUT/FF/BRAM、配置使用率、制約カバレッジ、構成バイナリのSHA-256は[AHB詳細とタイミング](ahb.md#配置配線後のタイミング余裕)を正本とする。** ここでは数値表を複製せず、検証対象と合否範囲を記録する。

再現用の入力ハッシュと合格配置は[verified-route](../../fpga/verified-route/)に保存され、[build.ps1](../../fpga/build.ps1)が生成入力との一致を確認する。`fpga/rtl/top.bin`と`fpga/rtl/alta_db/`はビルド生成物であり、Gitの常設ファイルではない。

## 現行RTLで確認した動作

- 240 MHz CPU／80 MHz BUSCLK間のAHB要求・応答ハンドシェイク、先行登録した読出しデータ、2サイクルエラー応答と連続アクセスをテストベンチで確認した。
- MEM所有権、NOR/SRAMの8 bitサイクル、POWER_FAIL時のアクセス遮断、バス返却、SPIの/CS排他をRTLで確認した。
- 64フレームPCM FIFO、80 MHzポリフェーズFIR、320 kHzサンプル受渡し、8 MHzの3次DSMについて参照モデルとの一致を確認した。
- SFCアドレス・制御からNORアドレスや/CEへのFPGA端子間遅延を配置配線済みネットリストから解析した。通常NOR読出しの最長経路概算は約99.1 nsで、FastROM 120 nsまでの残余約20.9 nsにPCB・SFC側の到着差・セットアップ等を含めて評価する必要がある。

## 未完了の検証

実機ではSlowROM 200 nsとFastROM 120 nsの全経路、バス衝突と出力OE、電源投入・遮断、CIC、NORプログラミング、SRAMバックアップ、SFCリセット解除、ゲームROM互換、音声端子の周波数特性・SNR・歪みを測定する。3D/USB映像、Jet/cmixer、将棋AIは統合ソフトウェアの実装・実証工程に属する。

変更過程の計測値は本番仕様から分離し、履歴はGitコミットで参照する。
