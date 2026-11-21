# SFCBuilder Rev.0.9 FPGA バス実装

対象は AG32VF407VGT6（AGRV2KL100）。[Rev.0.9のピン表](../Docs/hardware/pinout.csv)を [top.ve](top.ve) に反映。UART0とSPI0はAG32のハードIP、USBは固定ピン70/71をデバイスモードで使用する。PIN29/30を左右のDSM音声出力に使用する。

## クロック

RISC-VのSYSCLKは240 MHz、FPGAのBUSCLKとFIRは共通の80 MHz、DSMは水晶由来の8 MHz。AHBブリッジはアドレス受理後に待機を挟んで書込みデータを取り込み、応答データを登録してから `HREADYOUT` を上げる。割り込みはSYSCLKで同期し、CPU入力の前に1段追加している。NOR・SRAMのストローブ、MEM所有権切替、SPIデコーダはBUSCLKで動作する。SFCの直接ROM読出しは非同期。[AHB信号・周期・配置配線結果](../Docs/verification/ahb.md)

CPUファームウェアはPLLを起動してからFPGAのMMIOを使う。電源断退避でCPUだけを低速クロックに切り替える場合も、FPGAの80 MHzを供給するPLLは退避完了まで動作させる。SDKの `SYS_SwitchHSIClock()` はPLLを停止するため、この構成の退避中に呼び出すとFPGAのバス制御も停止する。

## RISC-V MMIO

| アドレス | 用途 |
|---|---|
| `0x60000000` | MAP_CONFIG。bit0 SFC有効、bit1 LoROM系、bit2 Ex形式、bits5:3 ROMサイズ、bit6 セーブSRAM、bit7 通信窓 |
| `0x60000004` | PIN_STATUS。bits7:0 MEM D、bit8 POWER_FAIL、bit9 USB VBUS、bit10 SD MISO、bit11 SFC /RESET、bit12 SFC /IRQ |
| `0x60000008` | BOOT_CONTROL。bit0 BOOT_MODE（固定応答）、bit1 BIOSオーバーレイ。いずれもRISC-Vが読み書きする |
| `0x6000000C` | BUS_CONTROL |
| `0x60001000 + 4 × n` | SFC通信レジスタへのCPU側アクセス。nは `0x00～0x0C` |
| `0x61000000–0x617FFFFF` | 外部NORの物理バイトアドレス |
| `0x62000000–0x6201FFFF` | 外部SRAMの物理バイトアドレス |

制御・通信レジスタは32ビット境界の32ビットアクセス。外部メモリは自然整列した8/16/32ビットアクセスを受け、リトルエンディアンの順で1～4回の8ビットサイクルに分ける。FPGAのBUSCLK 80 MHzにおけるRTL上の設定、ストローブ、保持はSRAMで50 ns、100 ns、50 ns、パラレルNORで56.25 ns、112.5 ns、56.25 ns。HREADYOUTで完了を待機し、範囲外・不整列・所有権条件を満たさない外部メモリアクセスではAHB ERRORを返す。NORのコマンド列、書込み・消去完了のポーリングはファームウェアが行う。

## 所有権と起動

1. リセット後はMAP_CONFIG=`0x28`。FPGAはSFC /RESETを保持してCPUにMEM所有権を渡す。CPUは外部SRAMの物理 `0x1E000～0x1FFFF` にBIOSを配置し、BOOT_CONTROLに `0x03` を書いてからMAP_CONFIGでSFCを有効化する。例えば4 MiB HiROMで通信窓を有効にする値は `0xA9`。
2. FPGAはMEMバッファとストローブを一度無効化し、切替ガードを経由してからSFC /RESETを解除する。SFC側の起動読出しに対し、FPGAがMEM Dを駆動して `$00:FFFC/FFFD → 00/80`、`$00:8000～8003 → 5C/00/60/2F` を返す。この6バイトのデコードはA6～A11を無視する。
3. `JML $2F6000` 後は、`$2F:6000～7FFF` が外部SRAM末尾8 KiBへマップされる。BIOSは通信コマンドでRISC-Vに切替を要求する。RISC-Vが BOOT_CONTROL に `0x02` を書くと、固定応答を解除して通常NORを有効にし、BIOS領域は維持する。BIOSがWRAMに移った後、RISC-Vが `0x00` を書くとBIOSオーバーレイを解除できる。
4. 実行中にCPUへMEMを渡す場合、65C816はWRAMへ移り、既存のIRQを処理して返却IRQだけを有効化してから `$5004` のbit0に1を書き、WRAM内で返却IRQを待つ。CPUへの貸出中は65C816からカートリッジを読書きしない。返却するまでIRQハンドラもWRAM上で実行する。
5. CPUはBUS_CONTROLのbit1に1を書いて返却を要求する。NORの内部書込みや消去の間はbit4をセットする。BUSY中に返却を予約してもCPUが所有権を保持し、NORの読出しで完了を確認できる。返却を予約した後の外部MEMアクセスは、このNOR読出しに限る。完了確認後にbit4をクリアすると、FPGAは進行中の転送を終えてSFCへ戻し、返却IRQを通知する。

BUS_CONTROL読出しのbit0はSFC所有、bit1はCPU所有、bit2は貸出要求、bit3はBIOSオーバーレイ、bit4はNOR BUSY、bit5は電源断退避の保持状態。

POWER_FAILを検出すると、FPGAはSFCをリセットに保持し、MEM所有権をCPUへ移す。電源が復帰してもCPU所有と割り込み `local_int[2]` を保持する。CPUは退避完了と電源復帰を確認してから、BUS_CONTROL（`0x6000000C`）へ `0x20` を書いて保持を解除する。同期済みのPOWER_FAILがHighなら解除要求は無効。通常のCPU貸出も同時に終了する場合は `0x22` を書く。どちらの解除操作もNOR BUSYの設定を保持する。

NORのストローブは、電源断信号を同期するBUSCLK立上りの後、立下りで開始する。同期済みのPOWER_FAILが開始候補と同じ立上りで有効になった場合、そのバイトを開始せずAHB ERRORを返す。開始済みのストローブと保持時間は完了し、残りのバイトは転送しない。全バイトを完了した転送は正常応答を返す。すでに書き込んだバイトは取り消せない。電源断時のSRAMアクセスは引き続き可能。

ゲーム実行時はBIOSオーバーレイを解除し、BIOSが使った物理 `0x1E000～0x1FFFF` もゲームのセーブSRAMマッピングに開放する。電源断時に永続退避する範囲は物理先頭120 KiB。

MEM D0～D7（PIN78～85）は双方向。FPGAはCPUの外部メモリ書込み、BIOS固定応答、SFC通信レジスタ読出しの間に駆動し、それ以外は出力をHi-Zにする。A6～A11のSFC側経路はU1、CPU側経路はU6を使用する。U6の入力につながるPIN55～60はCPU所有時にのみ駆動し、所有権切替中は両バッファの出力を無効化する。

## 双方向FIFOと割り込み

[SFC通信レジスタ仕様](../Docs/fpga/communication.md)の13オフセットを実装する。各FIFOは4バイト。SFCはTX_DATAに書いてRX_DATAを読み、CPUはTX_DATAを読んでRX_DATAに書く。各FIFOは受信側のデータレジスタ読出しで先頭を取り出す。FIFO_STATUSのbits2:0はTX件数、bits6:4はRX件数。満杯への書込みは破棄し、ERRORのbit0（TX）またはbit1（RX）をセットする。空の読出しは0を返す。

| IRQ_CONTROL / IRQ_STATUS | ビット |
|---|---|
| SFCコマンド保留 | 0 |
| CPU返信保留 | 1 |
| SFC向けRX FIFOデータあり | 2 |
| MEM返却通知 | 3 |

IRQ_CONTROLのbit0はCPU通知マスクで、コマンド保留、TX FIFOデータあり、貸出要求を `local_int[0]` に通知する。アプリ停止要求は `local_int[1]`、電源断退避は `local_int[2]`（SDKの `LOCAL_INT2_IRQn`）に通知する。電源断ハンドラから退避処理を別の実行コンテキストに移す場合は、同じ退避処理を再起動しないようCPU側で割り込みをマスクする。CPUはIRQ_STATUS bit0への1書込みでコマンド保留をクリアする。SFCはIRQ_STATUS bit1/3への1書込みで返信・返却通知をクリアする。CPUはSTATUS bit3でアプリ停止完了を反映する。CPUはERRORへの1書込みで対応ビットをクリアする。

REPLYは未ACKの返信を1件保持する。CPUは `0x60001024` のIRQ_STATUS bit1が0であることを確認してから、`0x6000100C` のREPLYに書き込む。未ACKの間に書き込むと、FPGAは旧返信を保持したままAHB ERRORを返す。旧返信ACK（SFCからIRQ_STATUS bit1への1書込み）が新しいREPLYの書込みと同じクロックに重なった場合は、新しい返信を格納して返信通知を保持する。

RISC-Vの通信処理からは [sfcbuilder_try_reply](include/sfcbuilder_reply.h) を使える。戻り値が `false` のときは呼出し側が未送信データを保持し、ACK後に再試行する。REPLYへの書込みは1つの通信処理に集約する。

## RISC-VのSPI接続

| 物理ピン | 信号 | CPU側の接続 |
|---|---|---|
| 15 | 共用SCK | SPI0_SCK |
| 16 | 共用MOSI | SPI0_SI_IO0 |
| 17 | 共用MISO | SPI0_SO_IO1の入力 |
| 18 | microSD /CS | FPGAのSPIデコーダ出力 |
| 23 | セーブ用SPI NOR /CS | FPGAのSPIデコーダ出力 |

CPUはSPI0を1ビットのSPIモードで使い、GPIO6のbits3:2に2ビットの選択値を書く。両ビットを1回のGPIO書込みで更新する。

| GPIO6 bits3:2 | 選択 |
|---|---|
| `00` | 無選択 |
| `01` | microSD |
| `10` | セーブ用SPI NOR |
| `11` | 予約。両方を非選択 |

GPIO出力ラッチを `00` に初期化してから両ビットを出力にする。リセット時とGPIOの出力有効前は両方の /CS がHigh。FPGAはGPIOの選択値と出力イネーブルをBUSCLKで登録してからデコードする。デバイスを切り替えるときは両方を非選択にするBUSCLKの1周期を挟む。CPUは前のSPI転送を完了し、GPIO出力の変更から最大3 BUSCLK周期（37.5 ns）の反映時間とデバイスの /CS タイミングを確保してから次のSCKを開始する。POWER_FAIL中もこの選択経路で退避先を操作できる。退避・復元処理はRISC-V側の共通ファームウェアが担当する。

## ビルド

PowerShellで `SnesBuilder/fpga` から実行する。

```powershell
./build.ps1
```

AGMのAgRV SDKとSupra Native、PlatformIO環境は、リポジトリと同じ親ディレクトリにある `AGM/AgRV_pio` と `AGM/pio-env` を使用する。音声を含む本番イメージをビルドし、通常・高速コーナーのセットアップとホールドが合格してから `rtl/top.bin` を更新する。作業先は `.pio/release-build/rtl`、合格レポートの出力先は `rtl/alta_db`。

既定ビルドは、リポジトリに同梱した `verified-route` の入力ハッシュを新しく生成したネットリスト・制約と照合し、合格配置を再解析して本番イメージを生成する。合格配置はSupra Native 2024.08.b0、シード1234で作成した。生成入力のハッシュにはツールのインストールパスも反映される。ハッシュが一致する保存済み配置がなければ、新たに配置配線する。

新規に配置配線する場合は `-Seed 1234` 等を指定する。保存済みの別の配置を取り込む場合は `-VerifiedRoute <ディレクトリ>` を指定する。従来の `-Audio` 付き呼出しも同じ本番構成を生成する。

[音声仕様とレジスタ](../Docs/fpga/audio.md) · [タイミング制約](timing.sdc)
