# SFC・ARM間通信と音源処理

Rev.0.7 / 基本設計段階

## 1. 役割分担

| 処理 | 主な担当 |
|---|---|
| ゲームロジック、キャラクター管理 | ARM |
| 座標変換、衝突判定、物理演算 | ARM |
| 3Dレンダリング、データ展開 | ARM |
| ファイル管理 | ARM |
| PPUレジスタ制御、VRAM DMA | SFC |
| コントローラ入力、表示タイミング | SFC |
| SPC700との通信 | SFC |
| 標準音源の生成・再生 | SFC APU |
| モノラル追加音源（Rev.0.7） | PSoC ARM + DVDAC、SFCカートリッジ外部音声入力 |

通信レジスタ、外部共有SRAM、双方向FIFOを利用する。ARM側はゲーム全体のロジックを実行することもできる。

## 2. 通信レジスタ

正式なベースアドレスは$00:5000、通信領域はシステムバンク$00～$3F/$80～$BFの$5000～$5FFFとする。extension_enableで有効化する。A0～A4のみを使用し、32バイトごとにミラーする。予約領域は実装済みレジスタとは区別する。

| オフセット | レジスタ | SFC側 | 機能 |
|---|---|---|---|
| $00 | COMMAND | W | ARMへの処理要求 |
| $01 | STATUS | R | bit0 BUSY、bit1 ARM所有、bit2 IRQ pending |
| $02 | REPLY | R | ARMからの応答 |
| $03 | BUS_CONTROL | R/W | R: bit0 ARM所有、bit1 隔離、W: 所有権要求 |
| $04 | TX_DATA | W | FIFO送信 |
| $05 | RX_DATA | R | FIFO受信 |
| $06 | FIFO_STATUS | R | FIFO状態 |
| $07 | IRQ_CONTROL | R/W | bit0 IRQ許可 |
| $08 | IRQ_STATUS | R/W | bit0 pending、W: ファームウェアによるクリア要求 |
| $09 | LENGTH_LO | R/W | 転送サイズ下位 |
| $0A | LENGTH_HI | R/W | 転送サイズ上位 |
| $0B | ERROR | R | エラー |
| $0C～$0F | 予約 | — | |
| $10～$1F | 予約 | — | 将来の引数・結果・間接アクセス等 |

Rev.0.7の通信レジスタは$00～$0Bの12アドレスを初期実装対象とし、予約アドレスはレジスタ応答を行わない。ARMへの書き込み通知には共通8bitメールボックスと、COMMAND・BUS_CONTROL・IRQ_CONTROL・IRQ_STATUS・LENGTH_LO・LENGTH_HIなどを識別できる3bit以上の種別を使用する。書き込み要求を1bitシーケンスで保持し、2FF CDCでARMへ通知する。ARMはデータと種別を処理し、REPLY・IRQ等を確定後にACKを更新する。ACKとシーケンスが一致するまでBUSYとし、BUSY中の新規書き込みは無視されるため、SFCはBUSY解除を待つ。CDCのセットアップ/ホールド、リセット復旧は実装時に検証する。

SFC→ARMはUDB内部割り込み、ARM→SFCはP15[2]のオープンドレイン/IRQ（SFC端子18）を使用する。ARMがpendingを保持し、IRQ許可かつSFC所有の場合に通知する。ポーリングも使用可能とする。ARM側のUDBアドレスはCreatorの配置に依存するためBIOS APIで抽象化する。

## 3. 共有SRAM

大容量データは128KiB外部SRAMを利用する。ARMが演算結果、画像等を書き込んだ後、SFCがバス所有権を取得し、データを読み出して利用する。

共通メモリバスの所有権は排他的であり、ARM所有時にはSFCは本体WRAMに展開したコードを実行する。意図しないカートリッジROMアクセスを防ぐ必要がある。

ARM所有中も$5000通信によって状態確認できる。A0～A4、A12～A15、A20～A23および制御信号をPSoCへ直接接続するため、3SB無効時も$5000領域のデコードに必要な信号を取得できる。SFC A19は3SB経由でMEM A19に接続し、PSoCへ直接入力しない。内部64KiB SRAMは直接マッピングせず、数KiB程度のデータはFIFO・DMA経由、大容量は外部共有SRAMを使用する。

## 4. 双方向FIFO・DMA

初期実装は基本6レジスタ、FIFO関連3レジスタ、LENGTH_LO/HI・ERRORの計12個とし、20アドレスを予約とする。32アドレス空間をすべて独立した記憶回路として実装しない。ARM内部のControl Register/Status Registerを利用する。

| パラメータ | 仕様 |
|---|---|
| データ幅・方向 | 8bit、SFC→ARMとARM→SFC独立 |
| FIFO深度 | 各方向4バイト（データパス内蔵FIFO） |
| 一時保持 | 各方向1バイト相当を想定 |
| データパス | 原則各方向1個、計2個 |
| DMA | 原則各方向1チャネル、計2個 |
| TX_DATA | SFC→ARM、SFC書き込み |
| RX_DATA | ARM→SFC、SFC読み出し |

ARM→SFCはARM/DMAがFIFOへ供給し、データパスA0/POに先頭バイトを事前準備する。SFCの有効な読み出し完了を検出してから次のバイトを準備する。SFC→ARMは/WRの終端でデータを一時保持し、CDCを経てPI/ALUから専用FIFOに格納する。FIFOは両方向ともシステムバスからARM/DMAでアクセスする。FIFOアクセスは外部NOR/SRAM所有権に依存させない。

FIFO_STATUSの暫定ビット割り当て:

| bit | 内容 |
|---:|---|
| 0 | TX_FULL |
| 1 | TX_EMPTY |
| 2 | RX_EMPTY |
| 3 | RX_FULL |
| 4 | TX_OVERRUN |
| 5 | RX_UNDERRUN |
| 6～7 | 予約 |

FULL/EMPTYは一時保持・処理中データも含めたSFCから観測できる状態を定義する。オーバーフロー・アンダーフローを検出し、満杯時の書き込みと空時の読み出しでFIFO状態を破壊しない制御を設ける。エラークリア、転送長の整合性、DMA要求、初期化、IRQ通知の詳細は実装設計で決定する。連続アクセス時に一時保持を上書きしないことをCDC設計と実機で検証する。

SFC DMAは固定アドレス$5005からVRAM/CGRAM/OAM等へ転送可能とする。NTSCで約2.68MB/s、1バイト約372.5ns。4バイトで約1.49µs分、40MHzの内部制御クロックなら1バイトあたり約15周期。SFC DMAには外部ウェイトを挿入できないため、バースト開始条件、DMA最悪供給遅延、プリフェッチ、FIFO空対策を検証する。連続DMAの達成は未検証。

ARM側ハードウェアレジスタ設計予算はControl 7個（所有権・システム、ACK/IRQ、有効化/REPLY、ROM設定、転送長LO/HI、FIFO制御を配分）、Status 4個（コマンドデータ、種別/状態、FIFO状態、転送/エラー）。具体的なビット割り当てはCreator配置とABIで決定する。データパスPI/POとStatus/Control経路の共有制約に注意する。32アドレスを超える将来の機能は間接インデックス／データポートを予約領域に割り当てられる。

## 5. 音源処理

標準音源はSFCのSPC700とS-DSPを使用する。Rev.0.7では独立した追加音源としてPSoC内蔵DVDACのモノラル出力を設け、SFC外部音声入力のL/Rへ同相信号を供給する。ARMは音源データ管理、圧縮データ展開、BGM・効果音の再生指示やゲーム状態に応じた音源制御を担当する。SFC側CPUはARMからの指示とデータに基づきSPC700と通信する。PSoC側の追加音声はSPC700の8チャンネルを消費せず、SFC本体の外部音声ミキサーで合成する。12bit DVDACは帯域制約があるため10bit・32kHzを初期評価目標とし、実効分解能はLPFと音声帯域を含め実測する。[audio.md](audio.md)参照。

## 6. USB経由のリアルタイム通信

外部ホストとの実行時通信は既存のFull-Speed USB、内部SRAM、UDB双方向FIFOおよびDMAを利用する。USBホストはPCまたはRaspberry Piで、PSoCはUSBデバイスとして動作する。

```text
PC / Raspberry Pi (USB host)
      |  USB Bulk IN / OUT
PSoC USB endpoints
      |  DMA / ARM protocol processing
Internal SRAM (buffers)
      |  DMA / UDB FIFO
SFC $5004 TX_DATA / $5005 RX_DATA
      |  65C816 / SFC DMA
PPU / SPC700 / Controller
```

ホスト→SFCでは画像タイル、タイルマップ、OAM、パレット、スクロール等のPPU制御命令、音源データや再生命令を扱う。SFC→ホストでは本体CPUが取得したコントローラ状態、ステータス、応答、デバッグ情報を扱う。PPUやAPUへの操作はSFC側制御プログラムが行い、USBやARMからPPUへ直接アクセスする構成ではない。

画像はホスト側でSFCタイル形式へ変換して送信する方式と、圧縮データをPSoC側で展開・変換する方式、描画命令を送信してSFCのBG・スプライト・スクロール機能を利用する方式を想定する。SFC DMAでは$5005からVRAM等へ転送する。大容量データの中間保存には必要に応じ外部128KiB SRAMを使用できるが、従来の排他的バス所有権とWRAM実行の制約を維持する。

Full-Speed USBは信号速度12Mbps、Bulk転送の理論上限は約1.216MB/s（64バイト×19トランザクション/msの理想条件）。SFC DMAは約2.68MB/sだが、通常表示中のVRAM書き込みはVBlankに制限される。NTSC 224ライン表示の場合のVBlank転送予算は約6KiB/フレーム、60Hz換算で約0.36MB/s程度の理想値であり、OAM/CGRAM転送、CPU処理、同期の時間を含む実効帯域はこれより小さい。画像全体の毎フレーム更新ではなく、差分タイル、部分更新、リソースの事前配置、ハードウェア描画を利用する。Forced Blankによる転送も用途に応じ検討可能とする。

標準音声はSPC700・S-DSPで再生する。PSoC内蔵DAC経由の追加モノラル音声も選択可能とする。ホストで生成した音声のBRRストリーミング（32kHzモノラル18KB/s、ステレオ36KB/sの符号化データ量）や、音源データ・再生命令の転送を候補とする。SPC700の4通信ポート経由での連続転送、再生バッファ管理、音声と映像の同期が必要である。

USBの平均転送速度がSFC DMAの瞬間速度より低いため、受信済みのデータを内部SRAMに蓄積してからSFC DMAのバーストを許可する。USBの到着間隔を4バイトFIFOだけで吸収する設計にはしない。転送長、バッファ残量、FIFO供給の最悪遅延、IRQ/ポーリング、USBとSFCの同時動作、欠損時の復旧を検証する。上記数値は設計参考値であり実測値ではない。
