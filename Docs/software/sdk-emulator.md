# Rev.0.9 SDK・エミュレータ・USB連携

SFC側はPVSnesLibで65C816 HiROM/SlowROM最小サンプルを実装する計画であり、RISC-V側はVS Code＋AgRV SDK、FPGA側はPrepare LOGIC＋Supra Nativeを用いる。FPGA本番RTLはCPU 240 MHz／BUSCLK・FIR 80 MHz／DSM 8 MHzで合成・配置配線済みだが、SDK・SFC表示プログラム・USBアプリの完成とは区別する。SFCBuilder SDKは`$5000 CPU_CONTROL`と`$5001 COMMAND`以降の64アドレス通信窓、FIFO/IRQ、ゲーム固有RISC-V処理の停止・再開、コプロセッサ演算、SRAM、メモリ所有権、NORローダをAPI化する。ares/bsnes/Snes9x等のエミュレータはROM4形式・容量ミラー・SRAM・通信・演算要求のゲームから見える挙動を再現する。

USB Full-SpeedではAG32をデバイス、PC/Raspberry Piをホストとし、画像・音声・操作・デバッグを双方向転送する。USBが接続されなくても通常ROMを起動可能とする。

## カートリッジからSFC本体への映像転送

FPGAとの物理インターフェースには実装済みの[CPU MMIO](../fpga/bus.md)と[通信レジスタ](../fpga/communication.md)を使用する。MEM貸出中の65C816はWRAM上で待機し、返却IRQの後にDMA/HDMAのカートリッジソース参照を再開する。RISC-Vと65C816が外部SRAMを同時に参照する方式ではない。

**3DデモとUSB映像転送モードはSFC側の表示方式を共通化する。** 共通の唯一の解像度目標は**152×104**であり、[3DデモのMode 3・BG1 8bpp統一方式](../prototypes/graphics.md)を使用する。左128画素は通常8bppタイルをVRAM DMAで更新し、右24画素は固定8bppタイルの参照するCGRAM RGB555をHDMAで更新する。上下各8走査線の強制ブランキングを利用し、表示する208走査線ではBG1VOFS HDMAにより4走査線で1画像ラインを参照する。解像度のストレッチ目標は設定しない。

```text
[カートリッジ側]
    3Dデモ: RISC-Vレンダリング ─┐
                                 ├→ SFC向け画像整形・8bppタイル/CGRAM/HDMA素材
    USB映像: PC等 → USB → AG32 ─┘
                                       ↓
                                 FPGA AHB・共有MEM調停
                                       ↓
                                    外部共有SRAM
                                       ↓ カートリッジバス
[SFC本体]                            65C816
                                ┌──────┴──────────┐
                                ↓                 ↓
                        強制ブランキング中      H-Blank HDMA
                        およびV-Blank DMA      CGRAM/BG1VOFS
                                ↓                 ↓
                           VRAM 8bpp           RGB555/スクロール
                                └──────┬──────────┘
                                       ↓
                                     PPU表示
```

**RISC-V/FPGA/USBコントローラからPPUへ直接書き込まず、65C816が共有SRAMからDMA/HDMAでPPUへ転送する。** 画像・HDMAテーブル等の実体は共有SRAMで受け渡す。`$5001 COMMAND`以降の64アドレス通信窓（`$5000`はCPU_CONTROL）、初期各方向4BのFIFO、IRQはコマンド、準備完了、フィールド同期、エラーの通知に使用する。MEM D0～D7はSFCとAG32で共有するため、同時アクセス可能なデュアルポートバッファではない。詳細は[bus.md](../fpga/bus.md)と[communication.md](../fpga/communication.md)を参照する。

### 共通画像形式とSFC側表示条件

論理解像度152×104、BG1 8bppタイルとRGB555動的色、CGRAM A/B割当て、HDMAの8チャネル、VRAM DMA所要量および強制ブランキングの条件は[3D／USB共通表示仕様](../prototypes/graphics.md#1-表示方式と目標解像度)を正本とする。ここにはSFCのタイミング・転送量の表を再掲せず、USB受信時の素材受渡し・遅延・同期処理のみを定義する。

描画元がJetでもUSBホストでも、RISC-Vが外部共有SRAMへ完成素材を配置した後に65C816がDMA/HDMAでPPUへ反映する。共有バス所有権の返却後にだけカートリッジソースを読む。表示フォーマット・フィールド同期の実機検証項目も[共通表示仕様](../prototypes/graphics.md)に集約する。

### USB映像転送モードの処理順

1. PC/Raspberry Pi側で入力映像のスケーリングとフレーム時刻管理を行い、AG32へUSB Full-Speedで素材を送る。USB画素符号化、圧縮、パケットと制御プロトコルは今後具体化するが、SFC側の**152×104・128＋24・強制ブランキング＋DMA/HDMA**は共通仕様として固定する。
2. ホストまたはAG32側で、128画素幅を207色パレットの8bpp番号に変換し、8×8タイルのビットプレーンを生成する。24画素幅はRGB555色情報とし、CGRAM A/BとBG1VOFSのHDMAテーブルを準備する。変換処理の担当はUSB負荷と内蔵SRAM使用量を測定して決める。
3. RISC-Vが外部共有SRAMへ完成素材を置き、FPGAが共有MEM所有権を調停する。65C816は完成通知を受けて非表示期間のVRAM DMAを計画し、可視期間ではCGRAM/BG1VOFS HDMAを使用する。
4. フィールド切替時に画像素材、A/Bパレット参照、HDMAテーブル、MEM所有権を同期し、USB受信が遅れた場合は**完成済みフィールドを保持する**。フィールド欠落時の扱いと表示遅延は測定で確定する。

1フィールドの画素情報は`6,656+2,496=9,152B`、60フィールド／秒で**549,120B/s**であり、USBプロトコルやタイル全更新のパディングを含まない。USB Full-Speedの12Mbit/sをPPUの書込み帯域と同一視しない。実効表示帯域は65C816、DMA/HDMAの時刻、共有MEM調停で決まる。USB映像デモでは受信帯域に加え、転送完了時刻、CGRAMの正常更新色数、フィールド同期、表示遅延を測定する。

## ゲーム固有RISC-VプログラムとFPGA演算器

SFCBuilderの共通ファームウェアはAG32内蔵Flashに常駐し、ゲームパッケージのRISC-Vコードは外部8MiB NORから内蔵SRAMへ展開して実行する。ゲーム用GCCリンクは内蔵SRAMを実行アドレスとし、共通Flash側のRAM領域と重複させない。共通ファームウェアのサービスは固定ABI/API経由で利用し、SFC側の65C816コードは`$5001 COMMAND`以降の汎用通信レジスタとFIFO/IRQを通じてRISC-V側へ処理を要求する。`$5000 CPU_CONTROL` bit0でゲーム固有処理の停止・再開を要求し、`$5002 STATUS` bit3で停止完了を確認する。

RISC-Vのゲーム固有コードは、内蔵Flash共通APIのJet（3Dレンダリング）・cmixer（16音、64kHzステレオPCM）を直接呼び出す。モデル・頂点・テクスチャ・音声素材の管理はゲーム固有のC/C++コードが担当し、65C816側へのメディア専用レジスタを追加しない。将棋AIでは同じRISC-Vを探索・評価に使用する。OSの3DロゴとDSMジングルはPPU初期化後に開始する。

RISC-VがFPGA内の演算アクセラレータを使う場合は、内部AHBにメモリマップした入力・制御・状態・結果レジスタをMMIO経由で操作する。演算器のアドレスは生成トップで確定する。ゲームパッケージには65C816 ROM・RISC-V実行イメージ・リソース・セーブ定義の配置情報を持たせ、NOR物理容量8MiBの範囲内で格納する。
