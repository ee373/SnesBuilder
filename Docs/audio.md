# PSoC追加モノラル音源（Rev.0.8）

2026-11-19 / 基本設計。確定した構成方針と、Creator・実機での未検証事項を区別する。

## 目的・構成

SFC標準SPC700/S-DSPを維持し、PSoC 5LP CY8C5287AXI-LP095内蔵DACから独立したモノラル音声を生成する。SFCカートリッジの外部アナログ音声入力31番（L）・62番（R）へ同じ信号を供給し、SFC内部のミキサーで標準ステレオ音声と合成する。標準APUの8音声チャンネルを追加音源で消費しない。

```text
ARM PCM生成/デコード → 内部SRAMバッファ → タイマー/DMA → DVDAC
    → P4[5] (PSoC物理83番) → LPF → MCP6001 (5V/RRIO)
    → AC結合・左右別出力抵抗 → SNES AUDIO_L(31)/AUDIO_R(62)
```

## DAC仕様と検証方針

採用CY8C52LP系列のハードウェアVDACは8bit・1基。PSoC Creator DVDACはディザリングで実効9～12bitを得る構成。1Vレンジで10bit・32kHzのモノラルPCMを初期評価目標とし、12bitは低帯域の評価モードとする。DVDACのコンポーネント更新レートと、LPF後の実効分解能・セトリング時間は別物であり、12bit/32kHzや10bit/32kHzでの実効精度は実測して確定する。スイッチング/ディザノイズと帯域の両立が必要。サンプル送信はタイマー/DMA/内部RAMリングバッファを優先し、ARM・USB・UDB FIFOとDMA資源を調停する。

## オペアンプとアナログ回路

5V単電源のRRIO・ユニティゲイン安定なMCP6001T-I/OT（SOT-23-5）を第一候補とする。1MHz GBW、スルーレート0.6V/µs級の低価格部品で、入力はDVDACの1Vレンジを想定する。LPFの次数/定数、バッファのゲインと負荷、左右入力への分岐、DCカット、出力抵抗、電源デカップリングは回路図・実機確認で決める。SFCの本体リビジョンによる外部音声入力負荷と音量差、起動停止時のポップノイズ、電源ノイズを測定する。

## 端子・バス設計との整合

PSoCのDVDACはP4[5]（TQFP-100物理83番）へ出力する。PSoC P4の同じ5VドメインではA0–A4をSFCアドレス入力、P4[6]をSFC A15入力、P4[7]をCPLD MEM_BUS_OE制御に使用する。追加音声のアナログ配線がデジタルI/Oと干渉しないようPSoC Creatorのアナログルーティングを検証する。

外部メモリの高速アドレス変換はLC4064V CPLDが担当し、音声のDMA/タイマーはPSoCの既存周辺回路を使用する。USB、通信FIFO、ARM演算とDVDACのDMA利用を調停する。ROMマッピングはHiROM・ExHiROM・LoROM・ExLoROMに対応し、音声出力方式はゲームのROM形式に依存しない。

## 必須検証

- [ ] PSoC CreatorでDAC0/DVDAC→P4[5]のアナログ配線とDAC資源適合を確認する。
- [ ] P4[5]のVDDA/VDDIO0、音声信号振幅、スイッチ抵抗、出力負荷を確認する。
- [ ] DVDAC 10bit/32kHzの実効帯域、S/N、歪、ディザリングノイズを測定する。
- [ ] フィルタおよびMCP6001の5V動作・負荷・SFC入力との音量整合を確認する。
- [ ] PSoC音声DMAとARM・FIFO・microSD・USBの並行実行を測定する。
- [ ] P4[7]のCPLD MEM_BUS_OE、P4[6]のSFC A15、P4[5]のDVDAC出力のPSoC Creator同時配置を確認する。

## 検証資料

[verilog/README.md](verilog/README.md) に独立した過去版のミラーリング検証（履歴資料）を収録。Pythonモデル384条件PASS。Verilogテストベンチの実行、Creatorの合成・配置、アナログ経路、実機での音質測定は未完了。
