# Rev.0.9 — FPGA PCM・FIR・DSMとアナログ出力

2026-11-21現行。CPU SYSCLK 240 MHz／FPGA BUSCLK・FIR 80 MHz／水晶基準DSM 8 MHzの本番RTLを使用する。RISC-Vが生成する64 kHz・16 bitステレオPCMを、FPGAがポリフェーズFIRで320 kHzに変換し、サンプル保持を経て8 MHzの左右独立3次DSMへ送る。音声出力はPIN29/30を使用する。

## 信号経路と精度

| 段 | 本番構成 |
|---|---|
| AHB PCM入力 | 64 kHz、左右各符号付き16 bit。バス・FIR共通の80 MHzで動く64フレームFIFO |
| 5倍補間と32タップFIR | 5倍線形補間と32タップFIRを5相の合成FIRに統合。入力履歴と固定12 bit係数を同じBRAMに格納 |
| 逐次乗算と積和 | 左右共用。符号付き16 bit PCM × 12 bit係数。係数を2 bitずつ6段で処理し、部分積は18 bit、積と積和は28 bit |
| FIR出力 | 320 kHz。丸め・飽和して左右各符号付き17 bit |
| 8 MHz側への受け渡し | 4フレーム×34 bitの非同期FIFO。320 kHzの値を8 MHzで25周期保持 |
| DSM | 左右独立の3次1 bit出力。積分器は各24 bit、8 MHz水晶基準 |
| アナログ | PIN29/30から受動RCとMCP6002による約22 kHzのアクティブLPFを経てSFC AUDIO L/Rへ接続 |

合成FIRの等価インパルス応答は320 kHz換算で非ゼロ係数40個。RTLは出力1フレームにつき各チャンネル9積の演算枠を使う。80 MHzで1フレームは250クロックで、カウンタ84で左、156で右の結果を確定し、244でステレオの結果を出力FIFOへ送る。ポリフェーズ係数はQ11で、各相の係数絶対値和の最大値は3,812。フルスケールPCMを含む積和の絶対値は124,911,616以下で、符号付き28 bitに収まる。FIR出力はPCMのスケールに対して小数部を1 bit増やし、`(積和 + 512) >>> 10` を −65,536〜65,535 に飽和させる。[係数・固定小数点演算のRTL](../../fpga/rtl/sfcbuilder_audio.v)

320 kHzから8 MHzへの変換はゼロ次保持で行う。周波数特性とSNDRは、受動RCと約22 kHzのアナログLPFを含む実機の音声端子で測定する。

## クロックドメインとDSM

AG32 PIN12/13に接続する既存の8 MHz水晶をDSMのクロック源とする。本番トップでは、`PIN_HSE_OUT` からPLLを経由せずDSMへ供給する。FIRはバス制御と同じ80 MHzの `BUSCLK` を使用する。[本番クロック設定](../../fpga/audio-clocks.ve) · [本番ビルド手順](../../fpga/build.ps1)

DSM側は非同期FIFOに2フレームたまってから読み出しを開始し、以後25クロックごとに1フレームを取得する。取得時にFIFOが空なら、その25クロックはゼロを入力する。左右の値は同時に更新する。PCM入力1フレームはFIR出力の5フレームに相当し、DSMの125クロック（15.625 µs）に対応する。

左右それぞれの3次DSMは24 bitの積分器3段と1 bit量子化器を使い、8 MHzの立上りごとに出力を更新する。雑音伝達関数の設計値は `(1−z⁻¹)³/(1−0.75z⁻¹)³`。17 bitのFIR出力は下位に0を2 bit付けて符号付き19 bitでDSMへ渡す。FIR出力の最大振幅は量子化器のフルスケールの約1/2。

## RISC-VのPCMレジスタ（AG32本番MMIO）

音声のCPU MMIOはワード境界に整列した32bitアクセスを使用する。

| アドレス | 名前 | 動作 |
|---|---|---|
| `0x60002000` | PCM | 書込み。下位16bitが左、上位16bitが右のsigned PCM。64フレームFIFOが満杯のときはAHB ERROR応答 |
| `0x60002004` | STATUS | 読出し。bits6:0はFIFO使用数、bit7は満杯、bit8はアンダーラン履歴 |
| `0x60002008` | CONTROL | 読出し・書込み。bit0で再生を開始・停止。リセット時は0 |

開始前に入力FIFOへ書き込める。再生中、64 kHzのPCM取込み時点で入力FIFOが空ならゼロを補い、アンダーランを記録する。停止時はフィルタ履歴をリセットし、アンダーランフラグをクリアする。未消費のPCMは入力FIFOに保持する。電源断サービス中はハードウェアが再生許可を解除する。停止が8 MHz側に同期されるとDSMの積分器をクリアし、PIN29/30をLowに固定する。許可中のゼロ入力は、約50%のビット密度のDSM出力になる。

[CPU用ヘッダー](../../fpga/include/sfcbuilder_audio.h)の `sfcbuilder_audio_refill(cm_process, buffer, capacity)` は、空きフレーム数だけcmixerを呼び出してFIFOへ転送する。共通ファームウェアで `cm_init(64000)` を呼び出し、同じ処理からFIFOに供給する。cmixerのライブラリ本体とゲーム固有の音源管理はRISC-V側のファームウェアプロジェクトでリンクする。 [cmixer公式ソース](https://github.com/rxi/cmixer)。

## アナログ出力

DAC兼用のPIN29/30は、FPGAの1 bitデジタル出力に割り当てる。

| チャンネル | AG32出力 | SFCカートリッジ端子 |
|---|---|---|
| 左 | PIN29 `DAC0_AUDIO_L` | 31 `AUDIO L` |
| 右 | PIN30 `DAC1_AUDIO_R` | 62 `AUDIO R` |

両チャンネルとも、受動RCで8 MHz帯のスイッチング成分を減衰させてから、MCP6002によるアクティブLPFへ入力する。アクティブLPFのカットオフ設計値は約22 kHz。LPFの次数、抵抗・容量、ゲイン、直流バイアス、出力振幅、負荷、電源ノイズ、クロストークは回路設計・実測で確定する。[FPGAピン割り当て](../../fpga/top.ve) · [基板の主要配線](../hardware/interface.md)

SFC標準SPC700/S-DSPの8chとは独立した追加ステレオ音声として出力し、標準音声全体をRISC-V側でEQする構成ではない。

## 実装・測定

Icarus VerilogでPCM FIFOの64フレームの順序、満杯時のAHB ERROR、アンダーラン、電源断停止を確認した。FIRの360フレームを固定小数点モデルと照合し、サンプル保持を139,222 DSMクロックで確認した。DSMは無音、正負最大入力、無音復帰のビット密度を確認した。

RTL試験は `fpga` から実行する。

```powershell
$out = Join-Path $env:TEMP 'sfcbuilder-tb-audio.vvp'
iverilog -g2012 -Irtl -s tb_audio -o $out rtl/sfcbuilder.v tests/tb_audio.v
vvp $out
```

音声は `./build.ps1` の本番構成に含まれる。配置配線後の通常コーナーではバス・FIR共用の80 MHz領域でセットアップ余裕 +1.666 ns。設計全体の最小余裕はセットアップ +0.220 ns、ホールド +0.080 ns。実機での測定項目は以下のとおり。[合成使用率と配置配線のタイミング余裕](../verification/ahb.md)

1. 80 MHz FIRと8 MHz DSMのクロック、PIN29/30の出力とアナログ経路を実機で確認する。
2. FIRとLPFを合わせた応答を測定し、12 bit係数と17 bit信号幅のモデルと照合する。
3. 3次DSMの安定性、8MHzビット列、64kHzサンプル周期、無音時のアイドルパターン、クリッピングからの復帰を測る。
4. FIRと約22kHzのアナログLPFの合成周波数特性、26kHzまでの応答、38kHz以上のイメージ、SNR/SINAD、THD+N、左右分離、EMI、出力振幅を測定する。
5. cmixer 16音、追加DSP、Jet 3D描画を同時使用した際のRISC-V負荷、サンプル欠落、内部SRAM容量、外部MEM帯域を測定する。

実証手順は[音声デモ計画](../prototypes/audio-demo.md)、配線は[hardware.md](../hardware/interface.md)、FPGAツールは[fpga-development.md](development.md)を参照する。

cmixer／追加DSP／サンプル管理など、RISC-V側で実装する音声処理は[音声ソフトウェア](../firmware/audio-runtime.md)に記載する。
