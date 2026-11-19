# バス調停・UDB・アクセスタイミング

Rev.0.8 / 2026-11-19。CPLDがSFC側の非同期メモリバスを制御し、PSoC UDBはSFC通信・FIFO・所有権ハンドシェイクを担当する。

## 1. SFCとARMのメモリバス所有権

NORとSRAMは23bitアドレス/8bitデータの共通MEMバスを使用する。このバスをSFCとPSoC ARMが同時に駆動することは許可しない。所有権はPSoCのFSMが管理し、SFC側はWRAMに展開した切替コードから要求と完了を確認する。

| 信号 | SFC所有 | 隔離中 | ARM所有 |
|---|---|---|---|
| CPLD MEMアドレス15出力 | 有効 | High-Z | High-Z |
| 16T245第2グループ（SFC A5–A12） | B→A有効 | High-Z | High-Z |
| PSoC MEM A0–A22 | High-Z | High-Z | GPIO駆動 |
| CPLD MEM /CE・/OE・/WE | 有効 | High-Z | High-Z |
| PSoC MEM /CE・/OE・/WE | High-Z | 非選択/High-Z | GPIO駆動 |
| 16T245第1グループ（SFC⇄MEMデータ） | アクセス種別による | High-Z | High-Z |
| PSoC MEM D0–D7 | High-Z | High-Z | 入出力 |
| PSoC SFC P0 D0–D7 | 通信/ブート時に入出力 | 通信可 | 通信可 |
| CPLD SPECIAL_SEL | 有効 | 有効 | 有効 |

所有権切替で**SPECIAL_SELは無効にしない**。ARMがMEMバスを使用している間でも、PSoCの独立した5V SFCデータポートP0[7:0]から$5000通信へ応答できる。SFCはARM所有中、ROMから命令をフェッチしないようWRAMコードを実行し、カートリッジROMを参照するIRQ/NMI/DMAを停止する。

## 2. ハードウェア切替ハンドシェイク

UDBとARMファームウェアは、少なくともSFC所有・隔離・ARM所有を明確に区別する。Rev0.8ではISO → QUIET → CONFIG → GUARD → OWNERという保護シーケンスを設計契約とし、細部のクロック数はPSoC Creatorと実機のHigh-Z実測で決定する。

1. SFCがWRAM実行へ移り、$5000 BUS_CONTROLからメモリ引渡しを要求する。
2. ARMは新規NOR/SRAMアクセスを停止し、進行中トランザクションの終了を確認する。UDBはSFC側とARM側のメモリストローブを禁止する。
3. PSoCはCPLD MEM_BUS_OEを無効側へ、16T245の第1・第2グループ/OEを非アクティブへ変更し、CPLD MEMアドレス/制御とデータ側を隔離する。
4. 外部メモリの/CE・/OE・/WEが非アクティブで、出力無効化に必要な待ち時間が経過した後、PSoCのMEM GPIOドライブモード/PRTx_BYPを変更する。
5. ARM所有を許可し、SFCに$5000のSTATUS/REPLYで通知する。返却時はPSoCのMEM出力を無効化してからCPLDと16T245を再有効化する。

同じノードにCPLDとPSoCの出力が接続されるため、**両方の駆動を同時に有効にする瞬間を作らない**。SFCはバス待ち状態をハードウェアで挿入できないため、アクセスサイクル中にARM割り込みだけで即時退避させる方式は採用しない。ROM/SRAMに対するSFCアクセス開始前に所有権を確保する。

## 3. SFC側のアクセス種別と制御

| アクセス | ROM /CE | SRAM /CE | 16T245第1グループ | PSoC P0 |
|---|---|---|---|---|
| NOR読出し | 有効 | 無効 | A→B（MEM→SFC） | 入力 |
| SRAM読出し | 無効 | 有効 | A→B（MEM→SFC） | 入力 |
| SRAM書込み | 無効 | 有効 | B→A（SFC→MEM） | 入力 |
| $5000読出し | 無効 | 無効 | High-Z | 出力 |
| $5000書込み | 無効 | 無効 | High-Z | 入力 |
| ブート固定値読出し | 無効 | 無効 | High-Z | 出力 |
| ARM所有 | CPLD側High-Z | CPLD側High-Z | High-Z | 通信に使用可能 |

SFC側読出し時、MEM /OEは選択メモリへの読出しを許可し、NOR/SRAMのデータが有効になる前に16T245のDIRと/OEが安定するよう設計する。SRAM書込み時は16T245がB→Aに切り替わった後にMEM /WEをアサートし、書込み終了後にMEMデータが保持される時間を保証する。NOR書込みはARM所有時にのみ実行し、PSoCが制御信号を駆動する。

メモリの/CE・/OE・/WEに非アクティブ状態を保証するプルアップを設ける。SRAMのCE2は電圧監視による保持制御を併用し、電源喪失時の誤書込みを防ぐ。

## 4. CPLDとPSoCの特殊領域処理

CPLDはROM/SRAMを高速にデコードすると同時に、システムバンクの$5000–$5FFFとBOOT_MODE中の$00:8xxx/$00:Fxxxに対してSPECIAL_SELを出力する。SPECIAL_SELは3.3V出力のまま5V VDDIO3のPSoC P3[5]へ入力し、PSoC側LVTTLしきい値で受ける。

PSoCはSFC A15（P4[6]）によりSPECIAL_SELを分類する。A15=0なら通信レジスタ、A15=1なら固定値ブート候補である。通信レジスタ選択にはSFC A0–A4（P4[0:4]）を使う。ブート候補はSFC所有時のMEMアドレス入力から下位・中位ビットを読み、$00:8000–8003/$00:FFFC–FFFDの6バイトに限定する。

特殊領域ではCPLDがNOR/SRAMの/CEおよび16T245第1グループ/OEを無効化する。PSoCはSFC P0だけで応答し、MEM P5の使用状態を変更しない。BOOT_MODE中もBIOS用$2F:6000–$2F:7FFFのSRAM窓は使用可能にする。ARM所有中の通信はBOOT_MODE解除後の$5000領域を対象とする。

## 5. PSoC UDBの担当機能

| 機能 | 実装主体 |
|---|---|
| ROM/SRAM高速アドレス変換と/CE・/OE・/WE | CPLD |
| バス所有権の状態機械とARMの構成ACK | PSoC UDB＋ARMファームウェア |
| $5000の32アドレス（実装12、予約20） | PSoC UDB |
| ブート固定6バイトの応答 | PSoC UDB |
| SFC⇄ARMメールボックスと割り込み | PSoC UDB＋ARM |
| 双方向4byte FIFO | UDBデータパスF0/F1など |
| DMA・CDC・連続転送制御 | PSoC UDB＋DMA |
| microSD SPI | PSoC UDBまたはARMソフトウェア、電圧変換はCPLD |
| SFC追加音声 | PSoC DAC/DVDAC＋DMA |

SFC側レジスタの/RDや/WRはPSoC P3[6:7]へ直接接続する。特殊領域のデコードはCPLDのSPECIAL_SELとSFC A15/A0–A4の組合せを利用する。F0/F1を使用するFIFOはARM/DMA側のクロックドメインとSFC側の非同期リード/ライトを、ラッチとトグル/ACK同期などで接続する。

UDB資源予算は高速ROMのデコード論理を除いたRev0.8用に再算定する。[udb-evaluation.md](udb-evaluation.md)を参照する。48 PLDの実合成利用率およびPSoC Creatorの配置は未検証である。

## 6. タイミング制約

FastROMの要求はカートリッジ側アクセス120ns以内、SlowROMは200ns以内を目標とする。現行選定NORのランダムアクセスは最大70ns、SRAMは45nsである。最長経路は単にNORの70nsではなく、次の最大値で判定する。

```text
NOR valid ≈ max(
    SFC_ADDR_to_NOR_ADDR + tACC,
    SFC_ROMSEL_to_NOR_CE + tCE,
    SFC_RD_to_NOR_OE + tOE
)
SFC_data_valid ≈ max(NOR_valid, 16T245_data_OE_valid)
                 + 16T245_data_propagation
```

NORのtACC/tCEは最大70ns、tOEは最大15nsである。CPLDの製品速度グレード7.5nsは論理経路の上限値を一律に保証する数値ではないので、Latticeの配置配線後のパス遅延を使う。MEMアドレスのA5–A12が16T245を経由する経路とCPLD経由の経路は別々に評価する。

SRAM書込みではSFCデータ→16T245→MEM DとCPLD /WEの到着差、書込みセットアップ/ホールド、ARM切替時のHigh-Z時間を調べる。$5000のレジスタアクセスには通信ウィンドウに割り当てられるSFCバス時間に対してSPECIAL_SEL→UDB出力→P0の遅延を評価する。

## 7. 実装検証

- Lattice論理合成、マクロセル・積項・リソース配分、OEごとのフィッタ検証。
- CPLDと16T245の全信号に対するバス所有権遷移と出力競合のテストベンチ。
- PSoC CreatorによるP0/P5の入力/出力切替、DSI・FIFO・CDC・IRQ、SWD、DVDACの配置検証。
- 70ns NORと45ns SRAMの最悪タイミング条件、FastROM 120ns、SlowROM 200nsの実測。
- 電源投入前後のプルアップ、SRAM保持、16T245制御ピンの3.3V適合性、SFCデータ信号のHIGH電圧適合性。
