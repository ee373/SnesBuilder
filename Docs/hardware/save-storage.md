# Rev.0.9 — セーブ用SPI NORとバンク配置

## デバイス、SPI選択と二重バンク

外部SRAM 128KiBは通常の3.3Vで駆動し、SFC電源断時の永続化先としてGigaDevice GD25Q20ETIGR（2Mbit=256KiB、SOIC-8）を1個設ける。SPI NORはmicroSD用のSPI0 SCK/MOSI/MISOを共有する。/CSの切替はCPUのGPIO6 bits3:2をFPGA内のSPIデコーダが登録して行い、AG32 PIN23にSPI NORの/CSを出力する。microSDの/CSはPIN18である。ゲームROM用S29GL064S（パラレル8MiB）とは接続・目的を分離する。

| 領域 | SPI NORアドレス | 内容 |
|---|---|---|
| Bank A | 0x00000～0x1FFFF（128KiB） | 物理SRAM先頭120KiBと世代番号・CRC・保存完了マーカー |
| Bank B | 0x20000～0x3FFFF（128KiB） | 同上、交互に更新 |

SRAM物理0x00000～0x1DFFF（120KiB）だけをバックアップ対象とし、0x1E000～0x1FFFF（8KiB）のSFC BIOS領域は起動時に別途展開する。起動時はBank A/BのCRCと完了マーカーで最新の有効な保存データを選び、SRAMへ復元した後に非採用側バンクを通常給電下で消去する。電源断後は消去済みのバンクへの書込みだけを行い、全データと管理情報の記録後に保存完了マーカーを最後に更新する。旧バンクのデータは新バンクの保存完了まで維持する。初回の有効バックアップが存在しない場合はSRAMを所定値に初期化する。書込みページ境界・消去単位・最大プログラム時間はGD25Q20Eのデータシートに従って実装する。

POWER_FAIL時の退避プログラムと復元判定は[ファームウェアのバックアップ仕様](../firmware/backup.md)、HiCAPと検出回路は[電源](power.md)を参照する。
