# Rev.0.9 — AG32 FPGA／AHB／共通メモリ所有権

SFCBuilderはSFCとAG32がパラレルNOR 8 MiB・外部SRAM 128 KiBの **8 bit共通データバス** を共有する。デュアルポートメモリではなく、FPGAが所有権とストローブを調停する。通常SFC ROM読出しではRISC-V/AHBを通らず、FPGAの非同期アドレス変換でNORに直接アクセスする。

## 実装済みRISC-V AHBアドレス

| CPUアドレス | FPGAのアクセス先 |
|---|---|
| `0x60000000` | MAP_CONFIG |
| `0x60000004` | PIN_STATUS |
| `0x60000008` | BOOT_CONTROL |
| `0x6000000C` | BUS_CONTROL |
| `0x60001000 + 4 × n`（n=0x00～0x0C） | SFC通信レジスタ13個 |
| `0x60002000` | PCM FIFO（左右signed 16 bitを書込み） |
| `0x60002004` | PCM STATUS |
| `0x60002008` | PCM CONTROL |
| `0x61000000–0x617FFFFF` | 8 MiBパラレルNOR |
| `0x62000000–0x6201FFFF` | 128 KiB外部SRAM |

MMIOは32 bit整列アクセスとし、外部MEMは自然整列した8／16／32 bitアクセスを1～4回の8 bit転送に変換する。80 MHz BUSCLK側で処理した結果を240 MHz SYSCLK側へ渡し、`HREADYOUT`を保持する。範囲外や不整列、所有権違反ではAHB ERRORを返す。CPUが直接メモリを参照する間もSFCから同じメモリを読めるという意味ではない。[AHB実装・STA](../verification/ahb.md)

## 物理バスと所有権

SFCのA6～A11はU1からMEMへ、CPU側のA6～A11はAG32 PIN55～60からU6へ伝える。二つのバッファを同時に有効化しない。A0～A5とA12～A22のメモリアドレスはFPGA側MUXが生成する。共通MEM D0～D7はPIN78～85、MEM制御4本はPIN61～64、U1/U6/U5の出力許可はPIN65～67に対応する。U5はSFC 5 VとMEM 3.3 V間の双方向データ変換器である。

所有権変更中はU1/U6/U5の出力とMEM制御を無効化し、バス競合を防ぐ。ゲーム実行中にCPUへ外部MEMを貸す場合、65C816は**WRAM上の待機処理とIRQハンドラ**へ移動してからSFC `$5004 BUS_CONTROL` bit0で貸出を要求する。貸出中は65C816、DMA、HDMAからカートリッジを参照しない。CPU側は `0x6000000C` のbit1で返却要求を出す。

NORが内部書込み・消去中ならBUS_CONTROL bit4でBUSYを通知し、返却はBUSY解除まで保留する。返却予約後にCPUが許されるNORアクセスは書込み・消去完了確認の読出しのみである。FPGAは進行中のバイト転送を完了してSFCへMEMを返し、IRQで通知する。貸出時間の強制打切りは行わない。MEM返却IRQを受けるまでWRAMから戻らない。

## SFC起動と電源断

リセット後のMAP_CONFIG初期値は `0x28`。CPUが物理SRAM `0x1E000–0x1FFFF` に8 KiB BIOSを展開し、BOOT_CONTROLを `0x03` として起動固定応答とBIOS窓を有効化する。ROM設定後にSFCを起動し、`JML $2F6000` からBIOSを実行する。BIOSからの移行時はCPUがBOOT_CONTROLを `0x02`、さらにオーバーレイ終了後 `0x00` として制御する。[FPGA起動手順](../../fpga/README.md)

POWER_FAIL時は新しいNORストローブを抑止し、CPUのMEM所有権を保持する。電源復帰後も自動で返却せず、退避完了を確認したCPUがBUS_CONTROL bit5への1書込みで保持を解除する。退避時にはFPGA BUSCLK 80 MHzを維持する。[電源断制御](../hardware/power.md)

## タイミング

SlowROM 200 nsを必須、FastROM 120 nsを目標とする。現行RTLはSupra Nativeで配置配線済みであるが、入力バッファ・NOR70 ns・U5を含めた最長読出し経路は概算約99.1 nsであり、PCB・SFC入力条件・セットアップの実機測定は残る。[本番検証結果](../verification/README.md)
