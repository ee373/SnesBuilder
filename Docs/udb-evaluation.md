# PSoC UDB・AG256の資源評価

Rev0.8改訂案 / 2026-11-19。AG256が高速ROM/SRAMアクセス、7段階ROM容量ミラー、共有バスOE/制御を担当する。PSoC UDBはSFCブート・16アドレス通信・FIFO・バス所有権FSM・SPIへ集中させる。

## 1. 物理資源とピン使用量

| デバイス | 数量 |
|---|---|
| PSoC CY8C5287AXI-LP095 | 24 UDB、48 PLD、192マクロセル、24データパス |
| PSoC物理I/O | 71/72本（予備P3[5]の1本） |
| AG256SL100 | 256 LUT/LE、80ユーザーI/O |
| AG256I/O | 入力31本＋出力23本=54/80、26本余裕 |
| 74LVC245A ×5 | 38/40レーン使用 |
| SN74LVC8T245 | 8/8データレーン使用 |

PSoC新ピンは[pinout.csv](pinout.csv)、AG256新ピンは[cpld-pinout.csv](cpld-pinout.csv)を正本とする。SFC直接アドレスはP3[0:3]のA0–A3だけ、SFC /RESETはP15[1]へ直接接続する。

## 2. UDBの機能区分と合成前予算

| 機能 | 実装方式 | UDB計画予算 |
|---|---|---:|
| $00:FFFC/FFFDと$00:8000–8003のブート6バイト | UDB組み合わせMUX、P0出力/OE | 2–4 |
| $5000–$500Fの16アドレス（12レジスタ、4予約） | UDBレジスタ・メールボックス、ARM管理 | 3–5 |
| TX/RX各4バイトFIFO | 各方向1データパスを第一候補＋DMA | 2–4 |
| 2FF CDC、SFC /IRQ、所有権FSM | UDB同期制御＋ARM GPIO設定ACK | 3–5 |
| microSD SPI Master | UDB SPI＋DMA、必要ならソフトSPI | 1–3 |
| **合計** | | **11–21 UDB（仮予算）** |

これは個別回路ごとの設計予算を単純合計した値であり、PSoC Creatorで合成して得た使用数ではない。GPIO端子への接続、UDBデータパス・PLDの資源共有、ブートROM用MUX、DVDACアナログ経路、24 UDBの配置配線は統合合成で確定する。DMAはシステム側ハードウェアを使い、DMAチャネルをUDB個数として二重計上しない。

## 3. UDBを使用しない機能

MEMアドレスA0–A22（23bit）とMEMデータD0–D7（8bit）はPSoC ARM＋GPIOで駆動する。MEM /CE_ROM・/CE_RAM・/OE・/WEもPSoC GPIOからAG256の入力へ与える。UDBに23bitアドレスラッチや8bitメモリデータバスを構築しない。NOR/ SRAMの高速デコード、LoROM/HiROM/Ex変換、128KiB–8MiB容量マスク、SFCとのデータ変換OEはAG256が担当する。

USB Full-Speedは専用USBブロック、DVDACはVDAC＋タイマー/DMAを使用する。SFC /RESET=P15[1]はレベル変換なしで直結し、ARMがオープンドレインLow保持・High-Z解放する。CFG相当のモード設定はP4 GPIOからLVC245A #4/#5経由でAG256へ渡す。

## 4. クロック境界と信号応答

SFC /RDの応答データは、UDB内で事前準備した定数、STATUS/REPLY、FIFO先頭を8bit MUXからP0へ直接出力し、SFCにARM処理や2FF同期の完了を待たせない。一方、SFC /WRで取り込んだデータ、FIFO消費イベント、メールボックス要求はトグル/ACK・2FF CDCを経てsys_clkで更新する。BUSY、FIFO_FULL/EMPTY、割り込みと消去/再読み出しの競合を検証する。

SFC DMAの約372.5ns/byteの連続受信に対して、4バイトFIFOへのDMA供給遅延がデータ欠落を起こさないよう、内部SRAMのリングバッファから補給する。USB到着レートとSFC DMA瞬時レートの差をFIFOだけで吸収しない。

## 5. AG256と残る検証

AG256の54物理ピン候補はメーカーのAG256/AG272 LQFP100 pinoutから選んだ。7段階容量マスクはROM A17–A22の上位ビットを条件付きで無効化し、HiROM/LoROMのMUXと共有する。数LUT級の追加という見積もりは合成前予測であり、全体256 LUTへの収容・OE条件とピンロックはAGM Supraで確認する。

FastROM 120nsの単純予算（LVC245A=6.3ns、NOR=70ns、8T245=4.4ns）ではAG256+その他に39.3ns、基板等へ5–10nsの余裕を配分するとAG256用29.3–34.3nsを見込む。AG256のピン間遅延は10ns目標、15ns暫定上限とする。ただしSFC /ROMSELとアドレスの到着差、NOR /CE起点70ns、P0ブート/通信応答、出力High-Zと基板負荷はこの単純予算と別に測定する。

**未実行の検証**：PSoC Creatorの統合合成・ピン/DSIルーティング・データパスFIFO配置・SIO（SD MISO/VBUS）の設定、AGM Supra合成/STA、Verilog実機同等シミュレーション、SFCハードウェア実測。Rev0.7のPython検証および11–21 UDB予算をRev0.8の実合格とみなさない。
