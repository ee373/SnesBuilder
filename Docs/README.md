# SFCBuilder

PSoC 5LPを使用したスーパーファミコン向け独自拡張カートリッジの開発計画。

- 設計リビジョン: Rev.0.7
- 資料更新日: 2026-11-18
- 開発状況: 基本設計段階

## 開発目的

SFCカートリッジに32ビットARM Cortex-M3を搭載し、新規SFCソフトウェアの開発・実行環境を構築する。Super FX、SA-1、DSPシリーズ、Cx4などと同様に本体を拡張する独自チップを、現代の半導体技術で実現する。

PSoCのUDBを固定チップセットとして使用し、SFCとの通信、外部メモリアクセス、バス調停を担当させる。ゲーム開発者はARMおよび65C816のプログラムを開発する。ARMはネイティブコードを実行し、SFC本体の65C816系CPU、PPU、SPC700、S-DSPも引き続き利用する。

本製品は既存ゲームの実行を主目的とするマジコンではない。既存ROMへの対応は副次的な機能とし、HiROM・ExHiROM切替と1MiB単位のROMハードウェアミラーリングを利用し、残る差異をソフトウェア変換で扱う。既存拡張チップの互換性は完成条件に含めない。

ARMはゲームロジック、3Dポリゴン描画、テクスチャマッピング、ソフトウェアレンダリング、多数のオブジェクト管理、衝突判定、物理演算、経路探索、AI、圧縮データ展開等を担当できる。SFC側を画面表示、音源制御、入力取得などに使用する非対称型マルチプロセッサ構成も想定する。

USBは開発時の書き込み・デバッグだけでなく、ゲーム実行中の外部ホストとの双方向通信にも利用する。現行Rev.0.7の回路を変更せず、PC・Raspberry PiからSFCの映像・音源・コントローラを利用する外部ホスト駆動モード、ARMと65C816を含む協調動作、Homebrew開発支援をソフトウェア拡張として検討する。詳細は[firmware.md](firmware.md)、[communication.md](communication.md)、[sdk-emulator.md](sdk-emulator.md)を参照する。

## 開発環境の第一段階（2026-11-17追加）

公開済みのPVSnesLibを用い、通常の **HiROM / SlowROM** イメージをビルドしてSFCBuilderのNORからSFC実機で起動することを最初の統合検証目標とする。PVSnesLibはMakeベースで65C816 C言語・アセンブリをビルドし、Visual Studio Codeをエディタとして利用できる。PVSnesLibのExHiROMは2026-11時点で正式対応していないため、HiROM起動検証後に対応を検討する。SFCBuilder本体のHiROM・ExHiROM両対応は変更しない。

その後、既存PVSnesLibへ追加可能なSFCBuilder通信ライブラリ、ARM用arm-none-eabi-gcc、両CPUのプログラム統合ビルドを段階的に実装する。自作ExHiROMカートリッジの書込み方式、3SB追加後の量産原価の概算、製品頒布の検討は[production.md](production.md)、具体的な未完了課題は[roadmap.md](roadmap.md)を参照する。

## 資料一覧

| ファイル | 内容 |
|---|---|
| [hardware.md](hardware.md) | 基本仕様、PSoC、全体構成、3SB、GPIO |
| [audio.md](audio.md) | PSoC DVDACモノラル出力、MCP6001、外部音声入力、未検証条件 |
| [memory.md](memory.md) | NOR、SRAM、HiROM・ExHiROM、ミラーリング、物理アドレス変換 |
| [bus-udb.md](bus-udb.md) | バス調停、UDB、データバス、タイミング |
| [power-cic.md](power-cic.md) | 電源、バックアップ、CIC |
| [communication.md](communication.md) | CPU間通信、共有SRAM、FIFO、音源 |
| [firmware.md](firmware.md) | BIOS、ARMロード、microSD、USB/SWD、起動、セーブ、パッケージ |
| [rom-compatibility.md](rom-compatibility.md) | 既存ROMのソフトウェア変換 |
| [sdk-emulator.md](sdk-emulator.md) | SDK、ツールチェーン、エミュレータ |
| [production.md](production.md) | 製品形態、BOM、製造原価、頒布 |
| [roadmap.md](roadmap.md) | 未確定事項、検証項目、開発工程、デモ開発方針（将棋AI・3D・多重PCM・USBストリーミング） |
| [references.md](references.md) | 技術資料と設計根拠 |
| [pinout.csv](pinout.csv) | TQFP-100の物理ピン割り当て案 |
| [verilog/README.md](verilog/README.md) | Rev.0.7の1MiBミラーリングRTLと検証 |
| [udb-evaluation.md](udb-evaluation.md) | RTLによる資源推定・検証結果 |

## 資料の扱い

本資料は2026年11月18日時点のRev.0.7統合設計資料である。部品候補・数値・コード例は会話時点の記録であり、物理ピン配置、電気的特性、論理合成、実機動作、製造価格は未確定または未検証の項目を含む。各資料に示す暫定案は確定済み仕様と区別する。ROMマッピングはHiROM・ExHiROM切替、ROMミラーリングは1MiB単位、SRAMは128KiB固定とする。ARM通信は$5000～$5FFF（32独立アドレス）、双方向割り込み・双方向FIFOを標準機能とする。microSD SPIはUDB資源に応じてハードウェアまたはARMソフトウェア実装とする。SlowROMを必須、FastROMをストレッチ目標とする。

最終目標は、ハードウェア、BIOS、SDK、ゲームパッケージ仕様、対応エミュレータを一体として整備し、SFC実機向けに新規ゲームを開発してデジタルまたは物理媒体で頒布できる環境を実現することである。

## SRAM起動BIOS・リセット制御（2026-11-18）

NORの8MiBをゲーム用に確保するため、SFC側BIOSイメージはPSoC内蔵Flashへ保持し、SFC起動時は外部SRAM末尾8KiBへ展開する。末尾8KiBは起動時に上書きされるためセーブ用途には使わず、ゲーム中のWork RAMには利用できる（永続セーブ120KiB、Work RAM最大128KiB）。PSoC起動がSFCより遅れても、P15[1]によるSFC側/RESETの再アサートと保持でBIOS展開時間を確保する。BIOSから通常NORゲームへの移行はSFC本体WRAM上の切替ルーチンを使う。詳細は[firmware.md](firmware.md)、[memory.md](memory.md)、[power-cic.md](power-cic.md)を参照する。リセット信号の双方向駆動と起動直後の安全性は未検証。Rev.0.7のA19配線を維持するため、UDBが$00:FFFCのリセットベクタと$00:8000の`JML $2F6000`を固定値で返す6バイト相当のブートROM方式を採用する。ジャンプ先$2F:6000は既存HiROM SRAMマッピングで物理SRAM末尾8KiBに対応する。BIOS起動直後に$5000通信でBOOT_MODEを解除し、通常NORマッピングに復帰する。UDBのデコード/タイミングと本体RESET端子の電気的条件は未検証である。

## Rev.0.7の変更（2026-11-18）

ROMのハードウェアミラーリングを1MiB単位（1～8MiB）とする。1MiB未満のゲームイメージはローダ側でデータを複製して1MiBの物理イメージに変換する。1MiB以上の整数MiB容量はハードウェア変換を使用し、中途半端な容量はローダで1MiB境界へ補完する。A19は74LVC16244の未使用チャネルを経由してMEM_A19へ接続し、P4[5]（83番）をDVDAC用モノラル音声出力候補として確保する。SFCの外部音声入力L/Rへ同一信号を供給し、SPC700とは独立した追加音声とする。5V単電源RRIOオペアンプはMCP6001T-I/OTを第一候補とする。DVDACの実効帯域、Creatorのアナログルーティング、フィルタとSFC入力レベルは未検証。RTL論理式と独立ソフトウェアモデルの384条件照合はPASS、HDLシミュレーションは未実行。詳細は[audio.md](audio.md)、[memory.md](memory.md)、[verilog/README.md](verilog/README.md)。
