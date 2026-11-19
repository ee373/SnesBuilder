# 外部メモリとROM/SRAMマッピング

Rev.0.8 / 2026-11-19。HiROM・ExHiROM・LoROM・ExLoROMへの対応、NORへの事前ミラー展開、128KiB共有SRAMの物理配線と起動窓を定義する。

## 1. 外部NOR Flash

| 項目 | 仕様 |
|---|---|
| 型番 | S29GL064S70TFI023 |
| 種類 | 3.3V非同期パラレルNOR、64Mbit（8MiB） |
| データ幅 | x8 |
| 論理バイトアドレス | A0–A22（23bit、8MiB） |
| ランダムアクセス | 最大70ns（アドレス・/CE起点） |
| /OEアクセス | 最大15ns（規定条件） |
| ページアクセス | 15ns（16バイトページ、条件成立時） |
| 書込バッファ | 最大256バイト |
| 消去 | 64KiB均一セクタ（モデル02） |
| パッケージ | TSOP-56 |

NORにはゲームプログラム、ARM用プログラム、画像・音源などのリソースを格納する。SFC側BIOS本体はPSoC内蔵Flashに保持し、起動時に外部SRAMへ展開する。ROMアクセスの/CE・/OE・アドレスはCPLDが生成し、データはSN74LVC8T245を介してSFCへ返す。NORへの消去・書込み時はARMが共通MEMバスを所有する。

**NOR 8bit（BYTE#=Low）の必須配線**：MEM A0→NOR DQ15/A-1（TSOP-56物理51番）、MEM A1→NOR A0（31番）、以降MEM A2–A22→NOR A1–A21へ接続する。NORのDQ0–DQ7をMEM D0–D7へ接続し、BYTE#（53番）を確実にLowに固定する。NOR RESET#・WP#/ACC・未使用DQ8–DQ14・電源端子・書込み制御の結線は回路図で確定する。書込みコマンドのバイトアドレスもこの配線で解釈する。

## 2. ROMマッピングとバンク構成

| マッピング | 対象容量 | 基本配置 |
|---|---|---|
| HiROM | 最大4MiB | 64KiBバンク |
| ExHiROM | 最大8MiB | 64KiBバンク＋4MiB領域切替 |
| LoROM | 最大4MiB | 32KiBバンク |
| ExLoROM | 最大8MiB | 32KiBバンク＋4MiB領域切替 |

ROMモードはゲーム起動前にARMからCPLDへ設定する。**HiROM系/LoROM系の基本ビット配列の違いはCPLDで変換**し、4MiB領域の選択および実際の物理イメージ配置はモード設定・ローダの配置契約で一致させる。通常ROM読出しでは、容量ミラーリングのための逐次演算を行わない。

| MEMアドレス | HiROM系の基本配置 | LoROM系の基本配置 |
|---|---|---|
| A0–A14 | SFC A0–A14 | SFC A0–A14 |
| A15 | SFC A15 | SFC A16 |
| A16 | SFC A16 | SFC A17 |
| A17 | SFC A17 | SFC A18 |
| A18 | SFC A18 | SFC A19 |
| A19 | SFC A19 | SFC A20 |
| A20 | SFC A20 | SFC A21 |
| A21 | SFC A21 | SFC A22 |
| A22 | 拡張4MiB領域/ROM設定 | 拡張4MiB領域/ROM設定 |

4MiBを超えるExマッピングではCPU側A23の極性やバンク割当てを考慮して物理A22を生成する。標準のExHiROM/ExLoROM配置ではバンク$80–$FFを物理前半、バンク$00–$7D側を後半へ対応させる。$7E–$7Fは本体WRAMが優先されるため、8MiB全域をSFCから連続して直接参照できるとはしない。全物理領域はARMからアドレス指定してアクセス可能とする。

ROMとSRAMの選択は別のデコードとし、ROMとして有効な領域でもSRAM選択時にはNORを非選択にする。ゲーム側ROMヘッダ・マップモード・FastROM指定はローダとSDKで一致させる。

### ROM容量ミラーリング（2冪容量はAG256、非2冪容量はNOR展開）

ROM_SIZE[2:0]をPSoC P4[1:3]からAG256へ入力し、ROMマッピング後の上位アドレスを7段階でマスクする。通常のSFC ROM読み出し中にARMやUDBを経由しない。

| ROM_SIZE | 容量 | 無効化する物理ROMアドレス |
|---|---|---|
| 000 | 128KiB | A17–A22 |
| 001 | 256KiB | A18–A22 |
| 010 | 512KiB | A19–A22 |
| 011 | 1MiB | A20–A22 |
| 100 | 2MiB | A21–A22 |
| 101 | 4MiB | A22 |
| 110 | 8MiB | なし |
| 111 | 予約 | ROM非選択 |

SFC側のHiROM/LoROMアドレス変換後にROM容量マスクを適用する。8MiBの場合はExHiROM/ExLoROMの4MiB領域切替を使用する。ROM容量マスクはSRAMおよびARM所有中のメモリ物理アクセスへ適用しない。

実容量が3MiBなどの非2冪容量では、元カートリッジのミラー規則を維持したままARMローダがNORへ次の2冪容量まで展開し、展開後の容量をROM_SIZEへ設定する。例えば768KiB→1MiB、3MiB→4MiB、5・6MiB→8MiBへ展開する。2冪容量のイメージは重複書込みせず、元容量分だけNORへ書き込む。

## 3. 128KiB共有SRAM

| 項目 | 仕様 |
|---|---|
| 型番 | CY62128EV30LL-45SXI |
| 構成 | 128K×8bit（1Mbit） |
| 動作電圧 | 2.2～3.6V |
| アクセス | 最大45ns |
| 書込サイクル | 最小45ns（個別tPWE、tSD条件はメーカー資料に従う） |
| データ保持電圧 | 最小1.5V |
| パッケージ | SOIC-32 |
| 保持用電源 | MAX40200＋BAS116＋CR2032、TPS3839による保護 |

共有SRAMはセーブデータ、ARMの演算結果、画像・音声・展開バッファ、SFC起動BIOSに利用する。先頭120KiB（0x00000–0x1DFFF）を永続セーブ候補とし、末尾8KiB（0x1E000–0x1FFFF）をBIOS起動時に上書きする。ゲーム実行時は全128KiBをワークとして利用できる。

### SRAMの固定物理接続

| SRAM端子 | 共通メモリバス |
|---|---|
| SRAM A0–A12 | MEM A0–A12 |
| SRAM A13 | MEM A16 |
| SRAM A14 | MEM A17 |
| SRAM A15 | MEM A18 |
| SRAM A16 | MEM A19 |

上記はPCB配線で固定し、SRAMのアドレス変換はCPLDが**MEM A16–A19の値を生成する**ことで実現する。ROMのA16–A19の意味とは区別する。PSoCがMEM所有時にSRAMへアクセスする場合も同じ固定配線を維持し、ファームウェアでバスアドレスを変換する。

```c
uint32_t sram_bus_address(uint32_t addr) {
    return (addr & 0x1FFF) | ((addr & 0x1E000) << 3);
}
```

### HiROM系SRAM

8KiBウィンドウを使用し、$20–$3F/$A0–$BF:$6000–$7FFFと、設定で有効となる$80–$BF:$6000–$7FFFの互換窓を扱う。SRAM物理A13–A16にSFC A16–A19を割り当てるため、MEM A16=SFC A16、A17=A17、A18=A18、A19=A19となる。

### LoROM系SRAM

32KiBウィンドウを使用し、$70–$7D/$F0–$FF:$0000–$7FFFを基本とする。SRAM物理A0–A14にSFC A0–A14、物理A15–A16にSFC A16–A17を割り当てる。そのため、CPLDがMEM A16=SFC A13、MEM A17=SFC A14、MEM A18=SFC A16、MEM A19=SFC A17を出力する。SRAMサイズ設定により小容量セーブ領域のミラーが必要なゲームについては、ローダ/SDKの規則を定義する。

SRAM選択時にはNORの/CEを非アクティブにし、SFC側/RD・/WRを5V→3.3V変換してAG256が適切な/OE・/WEを生成する。ARM所有時もメモリ制御の出力源はAG256のみとする。書込みセットアップ、終端ホールド、データ方向切替は[bus-udb.md](bus-udb.md)および[cpld.md](cpld.md)を参照する。

## 4. $5000通信とブート応答の領域

通信レジスタはシステムバンク$00–$3F/$80–$BF:$5000–$5FFFにEXTENSION_ENABLEで有効化する。**下位4bit（SFC A0–A3）の16アドレスを全通信窓内へミラー**し、実装12レジスタ・予約4アドレスとする。AG256が上位アドレスを判定してSPECIAL_SELをPSoC P3[4]へ出力し、PSoCはP3[0:3]のアドレスおよびP15[0]の/ROMSELと組み合わせてP0[7:0]から直接応答する。この通信はARM所有中も利用できる。

### 6バイト固定ブート応答

| SFC CPUアドレス | PSoC応答 | 用途 |
|---|---:|---|
| $00:FFFC | $00 | リセットベクタ下位 |
| $00:FFFD | $80 | リセットベクタ上位 |
| $00:8000 | $5C | JML命令 |
| $00:8001 | $00 | ジャンプ先下位 |
| $00:8002 | $60 | ジャンプ先中位 |
| $00:8003 | $2F | ジャンプ先バンク |

SFCはリセット解除後に$00:8000の`JML $2F6000`を実行する。BOOT_MODE中は$00:8xxx/$00:FxxxをCPLDがブート候補として扱い、PSoCが/ROMSEL、A3–A0、BOOT_MODEを使って6バイトのみに応答する。同じサイクルにNORは非選択、8T245データ側はHigh-Zとする。対象候補ウィンドウ内のそれ以外のアドレスを読まないことをBIOS/起動シーケンスで保証する。

$2F:6000–$2F:7FFFは起動時のHiROM系SRAM窓として常に利用でき、物理SRAM末尾8KiBへ対応する。ゲームがLoROM系でも起動直後はBIOS窓を維持し、WRAM実行コードからゲームモードへ遷移する。BOOT_MODE解除後に通常ROMを有効化し、SRAM実行中のBIOS窓の有効状態は必要な期間維持する。

## 5. タイミング契約と検証

SFC ROMアクセスの最長経路はSFCアドレス/ROMSEL→74LVC245A→AG256（マッピング＋容量マスク＋/CE）→NOR 70ns→8T245→SFC入力である。SFC A4–A11→LVC245A #1→MEM A4–A11の別経路も評価する。/CE起点70nsと/OE起点15nsを、実際の信号到着時刻を使って比較する。AG256の素子遅延だけでFastROM達成とは扱わず、フィッティング後のSTAと実機測定を完了条件とする。

[hardware.md](hardware.md)、[cpld.md](cpld.md)、[firmware.md](firmware.md)、[rom-compatibility.md](rom-compatibility.md)を関連する正本とする。
