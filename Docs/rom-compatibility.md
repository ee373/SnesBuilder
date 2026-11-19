# Rev.0.9 ROM互換

FPGAがHiROM/LoROM/ExHiROM/ExLoROMをデコードする。ROM_SIZEの7段階は128KiB（物理A17–A22を0）、256KiB（A18–A22を0）、512KiB（A19–A22）、1MiB（A20–A22）、2MiB（A21–A22）、4MiB（A22）、8MiB（マスクなし）とする。非2冪ROMはローダが元ROMの反復規則に沿ってNORへ事前展開する。SRAMにROMマスクは適用しない。HiROM基本アドレスはMEM A0–A21←SFC A0–A21、LoROM基本はMEM A0–A14←SFC A0–A14、MEM A15–A21←SFC A16–A22とし、MEM A22をEx領域の選択に使用する。WRAM/IO/特殊領域とSRAMの優先デコードも行う。SRAM物理0x1E000～0x1FFFFの8KiBへBIOSを配置する。

SFC通信領域$5000–$5FFFは64アドレス周期でミラーし、既存ゲームと競合する場合は無効化する。通常のSFC ROMアクセスはCPU/AHBを経由せずNORから直接応答する。SlowROM200nsを必須、FastROM120nsを目標とし、バンク境界・ヘッダ・リセット/割込みベクタ・NOR上位アドレス・SRAM選択と容量ミラーを実機で検証する。
