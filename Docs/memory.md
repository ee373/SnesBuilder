# Rev.0.9 外部NOR/SRAMとメモリマッピング

NORはS29GL064S70TFI023（8MiB、x8、70ns、TSOP56）、SRAMはLY62W1024SL-55SLI（128KiB、55ns、SOIC32）。3.3V共通MEM A0～A22・D0～D7を使用する。NOR BYTE# PIN53=GNDに固定し、MEM A0→NOR DQ15/A-1、MEM A1～A22→NOR A0～A21に1bitシフトして接続する。

| MEM | NOR信号 | NOR物理PIN |
|---|---|---:|
| A0 | DQ15/A-1 | 51 |
| A1 | A0 | 31 |
| A2 | A1 | 26 |
| A3 | A2 | 25 |
| A4 | A3 | 24 |
| A5 | A4 | 23 |
| A6 | A5 | 22 |
| A7 | A6 | 21 |
| A8 | A7 | 20 |
| A9 | A8 | 10 |
| A10 | A9 | 9 |
| A11 | A10 | 8 |
| A12 | A11 | 7 |
| A13 | A12 | 6 |
| A14 | A13 | 5 |
| A15 | A14 | 4 |
| A16 | A15 | 3 |
| A17 | A16 | 54 |
| A18 | A17 | 19 |
| A19 | A18 | 18 |
| A20 | A19 | 11 |
| A21 | A20 | 12 |
| A22 | A21 | 15 |

NOR DQ0～7物理PIN35,37,39,41,44,46,48,50をMEM D0～D7へ、/CE PIN32←AG32 PIN61、/OE PIN34←PIN63、/WE PIN13←PIN64、VCC PIN43・VIO PIN29は3.3V。/RESET PIN14は通常High、WP#/ACC PIN16は通常動作電位に設定する。

SRAM A0～A12←MEM A0～A12、SRAM A13～A16←MEM A16～A19。SRAM /CE1 PIN22←AG32 PIN62、/OE PIN24←PIN63、/WE PIN29←PIN64、CE2 PIN30は3.3Vへ接続し、チップ選択は/CE1およびAG32/FPGAのMEM制御で行う。SRAM D0～7物理PIN13,14,15,17,18,19,20,21←MEM D0～7、VCC PIN32は3.3V、GND PIN16=GND。SRAMアドレス物理端子はA0=12、A1=11、A2=10、A3=9、A4=8、A5=7、A6=6、A7=5、A8=27、A9=26、A10=23、A11=25、A12=4、A13=28、A14=3、A15=31、A16=2。

FPGAがHiROM/LoROM/ExHiROM/ExLoROMをデコードする。ROM_SIZEの7段階は128KiB（物理A17–A22を0）、256KiB（A18–A22を0）、512KiB（A19–A22）、1MiB（A20–A22）、2MiB（A21–A22）、4MiB（A22）、8MiB（マスクなし）とする。非2冪ROMはローダが元ROMの反復規則に沿ってNORへ事前展開する。SRAMにROMマスクは適用しない。HiROM基本アドレスはMEM A0–A21←SFC A0–A21、LoROM基本はMEM A0–A14←SFC A0–A14、MEM A15–A21←SFC A16–A22とし、MEM A22をEx領域の選択に使用する。WRAM/IO/特殊領域とSRAMの優先デコードも行う。SRAM物理0x1E000～0x1FFFFの8KiBへBIOSを配置する。

起動時はSRAM物理0x1E000～0x1FFFFの8KiBをBIOSに使用する。BIOS実行を終えてBIOS窓を解除した後は、ゲームのセーブSRAMマッピングで末尾8KiBも使用できる。電源断時の永続退避は物理先頭120KiBを対象とする。NOR書込み時はROM容量マスクを適用せず、完全な物理アドレスを使う。HiROM/LoROM/Ex形式の実際のバンク選択にはSFC WRAM/IOとSRAMの優先デコードを伴う。

## セーブデータ用256KiB SPI NOR

外部SRAM 128KiBは通常の3.3Vで駆動し、SFC電源断時の永続化先としてGigaDevice GD25Q20ETIGR（2Mbit=256KiB、SOIC-8）を1個設ける。SPI NORはmicroSD用のSPI0 SCK/MOSI/MISOを共有する。/CSの切替はCPUのGPIO6 bits3:2をFPGA内のSPIデコーダが登録して行い、AG32 PIN23にSPI NORの/CSを出力する。microSDの/CSはPIN18である。ゲームROM用S29GL064S（パラレル8MiB）とは接続・目的を分離する。

| 領域 | SPI NORアドレス | 内容 |
|---|---|---|
| Bank A | 0x00000～0x1FFFF（128KiB） | 物理SRAM先頭120KiBと世代番号・CRC・保存完了マーカー |
| Bank B | 0x20000～0x3FFFF（128KiB） | 同上、交互に更新 |

SRAM物理0x00000～0x1DFFF（120KiB）だけをバックアップ対象とし、0x1E000～0x1FFFF（8KiB）のSFC BIOS領域は起動時に別途展開する。起動時はBank A/BのCRCと完了マーカーで最新の有効な保存データを選び、SRAMへ復元した後に非採用側バンクを通常給電下で消去する。電源断後は消去済みのバンクへの書込みだけを行い、全データと管理情報の記録後に保存完了マーカーを最後に更新する。旧バンクのデータは新バンクの保存完了まで維持する。初回の有効バックアップが存在しない場合はSRAMを所定値に初期化する。書込みページ境界・消去単位・最大プログラム時間はGD25Q20Eのデータシートに従って実装する。

## ゲームパッケージとRISC-V実行イメージ

8MiBパラレルNORはSFCゲームROMだけでなく、ゲーム固有のRISC-V実行バイナリとリソースを格納する。内蔵Flashの共通ローダが、FPGA/AHB経由でNORからRISC-V実行イメージを読み出してAG32内蔵SRAM（CPU側0x20000000を基準とする実行領域）に展開し、エントリポイントへ制御を移す。ゲームROMの物理範囲とRISC-V/リソースの格納範囲はパッケージメタデータで区別し、NORの8MiB総容量内に収める。ROM容量マスクはSFC側のROMアクセスに適用し、ローダによる物理NORアクセスには適用しない。起動時のSFC BIOSは外部SRAM末尾8KiB、RISC-Vアプリケーションの命令フェッチ元はAG32内蔵SRAMとする。詳細は[firmware.md](firmware.md)を参照する。

## AG32の実装済みCPU側アドレス

CPU側の物理NORは `0x61000000–0x617FFFFF`、物理SRAMは `0x62000000–0x6201FFFF` にマップされる。AHBの自然整列8／16／32 bitアクセスはFPGAが8 bitバイト転送に変換する。MAP_CONFIGは `0x60000000`、BOOT_CONTROLは `0x60000008` に実装済みである。実際のアクセス幅、エラー応答、所有権条件は [AHB実装](verification/ahb-interface.md) と [FPGAプロジェクト](../fpga/README.md)を参照する。
