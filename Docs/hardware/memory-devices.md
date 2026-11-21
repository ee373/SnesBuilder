# Rev.0.9 — NOR/SRAMデバイスと物理配線

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

ROMバンク変換、容量マスクとSRAM優先デコードは[ROMマッピング](../../fpga/rom-mapping.md)で、CPUから見たAHBアドレスは[バス仕様](../../fpga/bus.md)で管理する。セーブ用256 KiB SPI NORの接続は[セーブストレージ](../save-storage.md)を参照する。
